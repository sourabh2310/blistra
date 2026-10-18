package com.blistra.auth.security;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.web.util.matcher.IpAddressMatcher;
import org.springframework.stereotype.Component;
import java.util.*;

/** Interpret forwarding headers only across explicitly trusted numeric proxy networks. */
@Component
public class TrustedClientAddress {
    private final List<IpAddressMatcher> proxies;
    public TrustedClientAddress(@Value("${blistra.security.trusted-proxies:}") String networks) {
        proxies=Arrays.stream(networks.split(",")).map(String::trim).filter(s -> !s.isEmpty())
            .map(s -> {
                if (!s.matches("[0-9a-fA-F:./]+") || !numeric(s.split("/",-1)[0])) throw new IllegalArgumentException("Trusted proxies must be numeric IP addresses or CIDR networks");
                return new IpAddressMatcher(s);
            }).toList();
    }
    public String resolve(HttpServletRequest request) {
        String peer=request.getRemoteAddr();
        if (!trusted(peer)) return peer;
        String header=request.getHeader("X-Forwarded-For");
        if (header==null || header.length()>2048) return peer;
        String[] hops=header.split(",",-1);
        if (hops.length>20) return peer;
        // Validate the entire chain first; never resolve attacker-supplied DNS.
        for (String hop:hops) if (!numeric(hop.trim())) return peer;
        String candidate=peer;
        for (int i=hops.length-1;i>=0 && trusted(candidate);i--) candidate=hops[i].trim();
        return candidate;
    }
    private boolean numeric(String address) {
        if (!address.matches("[0-9a-fA-F:.]+") || (!address.contains(":") && !address.contains("."))) return false;
        if (!address.contains(":") && !address.matches("[0-9]{1,3}(\\.[0-9]{1,3}){3}")) return false;
        try { new IpAddressMatcher(address); return true; }
        catch (IllegalArgumentException e) { return false; }
    }
    private boolean trusted(String address) {
        if (proxies.isEmpty() || !numeric(address)) return false;
        return proxies.stream().anyMatch(p -> p.matches(address));
    }
}
