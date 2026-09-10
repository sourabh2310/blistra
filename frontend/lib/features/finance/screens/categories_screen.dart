/// Categories tab and the create/edit category form.
library;

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../finance_controller.dart';
import '../finance_scope.dart';
import '../models.dart';
import 'form_helpers.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _categoryList(context, controller, CategoryType.income, 'Income categories'),
        _categoryList(context, controller, CategoryType.expense, 'Expense categories'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const CategoryFormScreen(),
            ));
          },
          icon: const Icon(Icons.add),
          label: const Text('New category'),
        ),
      ],
    );
  }

  Widget _categoryList(
    BuildContext context,
    FinanceController controller,
    CategoryType type,
    String title,
  ) {
    final List<Category> items =
        controller.categories.where((Category c) => c.type == type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('None yet.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final Category category in items)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(
                type == CategoryType.income
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: type == CategoryType.income
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(category.name),
              subtitle: category.isArchived
                  ? const Text('archived')
                  : null,
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CategoryFormScreen(category: category),
                ));
              },
            ),
          ),
      ],
    );
  }
}

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.category});

  final Category? category;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late CategoryType _type;
  bool _saving = false;
  bool _archiving = false;
  String? _error;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final Category? category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    _type = category?.type ?? CategoryType.expense;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(FinanceController controller) async {
    if (widget.category?.isArchived ?? false) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await controller.updateCategory(
          widget.category!.id,
          name: _name.text.trim(),
          type: _type,
        );
      } else {
        await controller.addCategory(name: _name.text.trim(), type: _type);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _archive(FinanceController controller) async {
    setState(() {
      _archiving = true;
      _error = null;
    });
    try {
      await controller.archiveCategory(widget.category!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _archiving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    final bool archived = widget.category?.isArchived ?? false;

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit category' : 'New category')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (archived)
                  const Card(
                    color: Colors.amber,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'This category is archived and cannot be edited.',
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (String? v) =>
                      FormValidators.required(v, label: 'Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoryType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.arrow_upward),
                  ),
                  items: [
                    for (final CategoryType type in CategoryType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                  ],
                  onChanged: archived
                      ? null
                      : (CategoryType? value) {
                          if (value != null) {
                            setState(() => _type = value);
                          }
                        },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_saving || archived) ? null : () => _save(controller),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Create category'),
                ),
                if (_isEditing && !archived) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _archiving ? null : () => _archive(controller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: _archiving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Archive category'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}