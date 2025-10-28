package outbounds

import (
	"net"
	"strings"
)

// userRouter is a PluggableOutbound that routes connections to different
// outbounds based on the authenticated user ID.
// If the userID matches an outbound's BindUser, that outbound is used.
// Otherwise, the default outbound is used.
type userRouter struct {
	Outbounds []UserOutboundEntry
	Default   PluggableOutbound
}

type UserOutboundEntry struct {
	BindUser string
	Outbound PluggableOutbound
}

func NewUserRouter(outbounds []UserOutboundEntry, defaultOutbound PluggableOutbound) PluggableOutbound {
	return &userRouter{
		Outbounds: outbounds,
		Default:   defaultOutbound,
	}
}

func (r *userRouter) selectOutbound(userID string) PluggableOutbound {
	if userID == "" {
		return r.Default
	}
	// Case-insensitive matching
	userIDLower := strings.ToLower(userID)
	for _, entry := range r.Outbounds {
		if entry.BindUser != "" && strings.ToLower(entry.BindUser) == userIDLower {
			return entry.Outbound
		}
	}
	return r.Default
}

func (r *userRouter) TCP(reqAddr *AddrEx, userID string) (net.Conn, error) {
	ob := r.selectOutbound(userID)
	return ob.TCP(reqAddr, userID)
}

func (r *userRouter) UDP(reqAddr *AddrEx, userID string) (UDPConn, error) {
	ob := r.selectOutbound(userID)
	return ob.UDP(reqAddr, userID)
}
