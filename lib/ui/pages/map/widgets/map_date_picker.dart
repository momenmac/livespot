import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class MapDatePicker extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;

  const MapDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: 36,
      constraints: BoxConstraints(maxWidth: 160),
      decoration: BoxDecoration(
        color: ThemeConstants.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ThemeConstants.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null && picked != selectedDate) {
              onDateChanged(picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: ThemeConstants.primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  _formatDate(selectedDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: ThemeConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
