import 'package:flutter/material.dart';

/// Rounded search input. A TextField rather than Material's SearchBar: the whole field
/// (48 px or more) is the tap target that screen readers report (SearchBar exposes only its
/// 24 px inner text line, which fails the tap-target guideline).
class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hintText,
      prefixIcon: const Icon(Icons.search),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
    ),
    onChanged: onChanged,
  );
}
