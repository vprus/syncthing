package config

import "testing"

func TestOptionsConfigurationNetworkingHelpers(t *testing.T) {
	opts := OptionsConfiguration{
		GlobalAnnEnabled:    true,
		LocalAnnEnabled:     true,
		RelaysEnabled:       true,
		NATEnabled:          true,
		StunKeepaliveMinS:   20,
		StunKeepaliveStartS: 180,
	}

	if !opts.GlobalDiscoveryEnabled() || !opts.LocalDiscoveryEnabled() || !opts.RelayTransportEnabled() || !opts.NATTraversalEnabled() {
		t.Fatal("expected classic network features to be enabled")
	}
	if opts.IsStunDisabled() {
		t.Fatal("expected STUN to remain enabled")
	}

	opts.TailscaleEnabled = true

	if !opts.GlobalDiscoveryEnabled() {
		t.Fatal("expected global discovery to remain enabled in tailscale mode")
	}
	if opts.LocalDiscoveryEnabled() {
		t.Fatal("expected local discovery to be disabled in tailscale mode")
	}
	if opts.RelayTransportEnabled() {
		t.Fatal("expected relays to be disabled in tailscale mode")
	}
	if opts.NATTraversalEnabled() {
		t.Fatal("expected NAT traversal to be disabled in tailscale mode")
	}
	if !opts.IsStunDisabled() {
		t.Fatal("expected STUN to be disabled in tailscale mode")
	}
}
