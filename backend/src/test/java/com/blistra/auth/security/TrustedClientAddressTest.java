package com.blistra.auth.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import static org.assertj.core.api.Assertions.*;

class TrustedClientAddressTest {
    private MockHttpServletRequest request(String peer,String hops) {
        var request=new MockHttpServletRequest();request.setRemoteAddr(peer);
        request.addHeader("X-Forwarded-For",hops);return request;
    }
    @Test void defaultsToSocketPeerAndIgnoresForgedHeaders() {
        assertThat(new TrustedClientAddress("").resolve(request("203.0.113.1","1.2.3.4"))).isEqualTo("203.0.113.1");
        assertThat(new TrustedClientAddress("10.0.0.0/8").resolve(request("203.0.113.1","1.2.3.4"))).isEqualTo("203.0.113.1");
    }
    @Test void walksRightToLeftUntilFirstUntrustedHop() {
        var resolver=new TrustedClientAddress("10.0.0.0/8,2001:db8:1::/48");
        assertThat(resolver.resolve(request("10.1.1.1","1.2.3.4,203.0.113.6,10.1.2.1"))).isEqualTo("203.0.113.6");
        assertThat(resolver.resolve(request("2001:db8:1::1","2001:db8:2::2"))).isEqualTo("2001:db8:2::2");
    }
    @Test void malformedChainsCannotTriggerDnsOrBypassTheProxyBoundary() {
        var resolver=new TrustedClientAddress("10.0.0.0/8");
        for (String hops:new String[]{"evil.example.com","unknown,1.2.3.4","999.999.999.999","1.2.3.4,", "[::1]:9000"})
            assertThat(resolver.resolve(request("10.1.1.1",hops))).isEqualTo("10.1.1.1");
        assertThatThrownBy(() -> new TrustedClientAddress("proxy.example.com")).isInstanceOf(IllegalArgumentException.class);
    }
}
