// Copyright (C) 2026 The Syncthing Authors.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

package tailscaleutil

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"tailscale.com/tsnet"

	"github.com/syncthing/syncthing/lib/config"
)

var errDisabled = errors.New("tailscale transport disabled")

type Service struct {
	cfg             config.Wrapper
	defaultStateDir string

	mut    sync.Mutex
	server *tsnet.Server
}

func New(cfg config.Wrapper, defaultStateDir string) *Service {
	return &Service{
		cfg:             cfg,
		defaultStateDir: defaultStateDir,
	}
}

func (s *Service) Enabled() bool {
	return s.cfg.Options().TailscaleEnabled
}

func (s *Service) Dial(ctx context.Context, network, addr string) (net.Conn, error) {
	server, err := s.get()
	if err != nil {
		return nil, err
	}
	return server.Dial(ctx, network, addr)
}

func (s *Service) Listen(network, addr string) (net.Listener, error) {
	server, err := s.get()
	if err != nil {
		return nil, err
	}
	return server.Listen(network, addr)
}

func (s *Service) AdvertiseURLs(scheme string, port int) []*url.URL {
	server, err := s.get()
	if err != nil {
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	status, err := server.Up(ctx)
	if err != nil {
		return nil
	}

	portStr := strconv.Itoa(port)
	seen := make(map[string]struct{})
	add := func(host string, urls *[]*url.URL) {
		if host == "" {
			return
		}
		u := &url.URL{
			Scheme: scheme,
			Host:   net.JoinHostPort(host, portStr),
		}
		if _, ok := seen[u.String()]; ok {
			return
		}
		seen[u.String()] = struct{}{}
		*urls = append(*urls, u)
	}

	var urls []*url.URL
	if status.Self != nil {
		add(strings.TrimSuffix(status.Self.DNSName, "."), &urls)
	}
	for _, ip := range status.TailscaleIPs {
		add(ip.String(), &urls)
	}
	return urls
}

// AuthURL returns the Tailscale auth URL if the node is waiting for
// authorisation, or an empty string if already running. tsnet uses an
// in-process, in-memory local API (no daemon, no network round-trip), so
// calling Status on every GUI poll is cheap and there is no need to cache.
func (s *Service) AuthURL() string {
	server, err := s.get()
	if err != nil {
		return ""
	}
	lc, err := server.LocalClient()
	if err != nil {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	status, err := lc.Status(ctx)
	if err != nil {
		return ""
	}
	return status.AuthURL
}

func (s *Service) Serve(ctx context.Context) error {
	<-ctx.Done()
	return s.Close()
}

func (s *Service) Close() error {
	s.mut.Lock()
	defer s.mut.Unlock()

	if s.server == nil {
		return nil
	}

	err := s.server.Close()
	s.server = nil
	return err
}

func (s *Service) get() (*tsnet.Server, error) {
	if !s.Enabled() {
		return nil, errDisabled
	}

	s.mut.Lock()
	defer s.mut.Unlock()

	if s.server != nil {
		return s.server, nil
	}

	opts := s.cfg.Options()
	stateDir := opts.TailscaleStateDir
	if stateDir == "" {
		stateDir = filepath.Join(s.defaultStateDir, "tsnet")
	}

	hostname := opts.TailscaleHostname
	if hostname == "" {
		hostname = "syncthing"
		if systemHostname, err := os.Hostname(); err == nil && systemHostname != "" {
			hostname = "syncthing-" + systemHostname
		}
	}

	s.server = &tsnet.Server{
		Dir:        stateDir,
		Hostname:   hostname,
		ControlURL: opts.TailscaleControlURL,
		UserLogf: func(format string, args ...any) {
			slog.Info("Tailscale", slog.String("message", fmt.Sprintf(format, args...)))
		},
		Logf: func(format string, args ...any) {
			slog.Debug("Tailscale", slog.String("message", fmt.Sprintf(format, args...)))
		},
	}

	return s.server, nil
}
