package outbounds

import (
	"net"

	"github.com/apernet/hysteria/extras/v2/outbounds/speedtest"
)

const (
	SpeedtestDest = "@SpeedTest"
)

// speedtestHandler is a PluggableOutbound that handles speed test requests.
// It's used to intercept speed test requests and return a pseudo connection that
// implements the speed test protocol.
type speedtestHandler struct {
	Next PluggableOutbound
}

func NewSpeedtestHandler(next PluggableOutbound) PluggableOutbound {
	return &speedtestHandler{
		Next: next,
	}
}

func (s *speedtestHandler) TCP(reqAddr *AddrEx, userID string) (net.Conn, error) {
	if reqAddr.Host == SpeedtestDest {
		return speedtest.NewServerConn(), nil
	} else {
		return s.Next.TCP(reqAddr, userID)
	}
}

func (s *speedtestHandler) UDP(reqAddr *AddrEx, userID string) (UDPConn, error) {
	return s.Next.UDP(reqAddr, userID)
}
