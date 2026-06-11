import 'package:flutter/material.dart';

class AddLocationInput {
  AddLocationInput({
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.requiredMinutes,
  });

  final String name;
  final String street;
  final String city;
  final String state;
  final String zip;
  final int requiredMinutes;
}

class AddLocationSheet extends StatefulWidget {
  const AddLocationSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.logMinuteOptions,
    this.initialInput,
    this.errorMessage,
  });

  final String title;
  final String submitLabel;
  final List<int> logMinuteOptions;
  final AddLocationInput? initialInput;
  final String? errorMessage;

  @override
  State<AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends State<AddLocationSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();

  int _selectedMinutes = 20;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final AddLocationInput? initial = widget.initialInput;
    if (initial != null) {
      _nameController.text = initial.name;
      _streetController.text = initial.street;
      _cityController.text = initial.city;
      _stateController.text = initial.state;
      _zipController.text = initial.zip;
      _selectedMinutes = initial.requiredMinutes;
    }

    if (!widget.logMinuteOptions.contains(_selectedMinutes) &&
        widget.logMinuteOptions.isNotEmpty) {
      _selectedMinutes = widget.logMinuteOptions.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  String _capitalizeWord(String value) {
    if (value.isEmpty) {
      return value;
    }
    final String lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _toTitleCase(String input) {
    return input
        .trim()
        .split(RegExp(r'\s+'))
        .where((String segment) => segment.isNotEmpty)
        .map((String token) {
      return token.split('-').map((String part) {
        return part.split("'").map(_capitalizeWord).join("'");
      }).join('-');
    }).join(' ');
  }

  bool _hasMissingRequiredValues(AddLocationInput input) {
    return input.name.trim().isEmpty ||
        input.street.trim().isEmpty ||
        input.city.trim().isEmpty ||
        input.state.trim().isEmpty ||
        input.zip.trim().isEmpty;
  }

  void _submit() {
    final AddLocationInput input = AddLocationInput(
      name: _toTitleCase(_nameController.text),
      street: _toTitleCase(_streetController.text),
      city: _toTitleCase(_cityController.text),
      state: _stateController.text.trim().toUpperCase(),
      zip: _zipController.text.trim(),
      requiredMinutes: _selectedMinutes,
    );

    if (_hasMissingRequiredValues(input)) {
      setState(() {
        _submitError = 'Please fill name, street, city, state, and ZIP.';
      });
      return;
    }

    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_submitError != null ||
                      widget.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _submitError ?? widget.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Client Name',
                      hintText: 'Smith Residence',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _streetController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street',
                      hintText: '123 Main St',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cityController,
                          onChanged: (_) {
                            if (_submitError != null) {
                              setState(() {
                                _submitError = null;
                              });
                            }
                          },
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          onChanged: (_) {
                            if (_submitError != null) {
                              setState(() {
                                _submitError = null;
                              });
                            }
                          },
                          textInputAction: TextInputAction.next,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _zipController,
                    onChanged: (_) {
                      if (_submitError != null) {
                        setState(() {
                          _submitError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'ZIP',
                      hintText: '75201',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedMinutes,
                    decoration: const InputDecoration(
                      labelText: 'How long to log (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.logMinuteOptions.map((int minutes) {
                      return DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes minutes'),
                      );
                    }).toList(),
                    onChanged: (int? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedMinutes = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
