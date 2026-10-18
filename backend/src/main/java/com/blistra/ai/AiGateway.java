package com.blistra.ai;

import java.util.List;
import java.util.Map;

public interface AiGateway {
    String reply(List<Map<String, String>> messages);
}
