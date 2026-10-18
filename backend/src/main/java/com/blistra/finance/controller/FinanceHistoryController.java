package com.blistra.finance.controller;
import com.blistra.finance.application.FinanceHistoryService;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController
@RequestMapping("/api/v1/finance/history")
public class FinanceHistoryController {
    private final FinanceHistoryService history;
    public FinanceHistoryController(FinanceHistoryService history) { this.history=history; }
    @GetMapping public List<Map<String,Object>> list(@RequestParam(required=false) UUID groupId,
            @RequestParam(required=false) UUID friendId,
            @RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="100") int size) {
        return history.list(groupId,friendId,page,size);
    }
}
