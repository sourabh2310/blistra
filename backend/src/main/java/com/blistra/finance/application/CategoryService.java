package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.finance.domain.Category;
import com.blistra.finance.domain.CategoryStatus;
import com.blistra.finance.dto.CategoryRequest;
import com.blistra.finance.dto.CategoryResponse;
import com.blistra.finance.repository.CategoryRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class CategoryService {

    private final CategoryRepository categoryRepository;
    private final CurrentUserProvider currentUserProvider;
    private final FinanceMapper mapper;

    public CategoryService(CategoryRepository categoryRepository,
                           CurrentUserProvider currentUserProvider,
                           FinanceMapper mapper) {
        this.categoryRepository = categoryRepository;
        this.currentUserProvider = currentUserProvider;
        this.mapper = mapper;
    }

    @Transactional
    public CategoryResponse create(CategoryRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Category category = new Category(user, request.getName(), request.getType(), CategoryStatus.ACTIVE);
        return mapper.toCategoryResponse(categoryRepository.save(category));
    }

    public List<CategoryResponse> list() {
        User user = currentUserProvider.getCurrentUser();
        return categoryRepository.findAllByUserIdOrderByNameAsc(user.getId()).stream()
                .map(mapper::toCategoryResponse)
                .toList();
    }

    public CategoryResponse get(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        return mapper.toCategoryResponse(category);
    }

    @Transactional
    public CategoryResponse update(UUID id, CategoryRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        if (category.getStatus() == CategoryStatus.ARCHIVED) {
            throw new BadRequestException("Cannot update an archived category");
        }
        category.setName(request.getName());
        category.setType(request.getType());
        return mapper.toCategoryResponse(categoryRepository.save(category));
    }

    @Transactional
    public void archive(UUID id) {
        User user = currentUserProvider.getCurrentUser();
        Category category = categoryRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Category not found"));
        if (category.getStatus() == CategoryStatus.ARCHIVED) {
            throw new BadRequestException("Category is already archived");
        }
        category.setStatus(CategoryStatus.ARCHIVED);
        categoryRepository.save(category);
    }
}