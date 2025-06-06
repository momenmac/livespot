import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:intl/intl.dart';

class DatePickerWidget extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime selectedDate;

  const DatePickerWidget({
    super.key,
    required this.onDateSelected,
    required this.selectedDate,
  });

  @override
  State<DatePickerWidget> createState() => _DatePickerWidgetState();
}

class _DatePickerWidgetState extends State<DatePickerWidget> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Theme-aware colors
    final backgroundColor =
        isDarkMode ? theme.scaffoldBackgroundColor : Colors.white;

    final headerColor = isDarkMode ? theme.cardColor : ThemeConstants.greyLight;

    final headerTextColor =
        isDarkMode ? theme.textTheme.titleLarge?.color : ThemeConstants.black;

    final dayTextColor =
        isDarkMode ? theme.textTheme.bodyMedium?.color : ThemeConstants.grey;

    // Calculate a better height that adapts to screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.75; // Max 75% of screen height

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? theme.dividerColor
                      : ThemeConstants.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? theme.dividerColor : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TextStrings.selectDate,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: headerTextColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onDateSelected(DateTime.now());
                    Navigator.pop(context);
                  },
                  child: Text(
                    TextStrings.today,
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Calendar view - increased height
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                children: [
                  // Month header with navigation
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _currentDate = DateTime(
                                _currentDate.year,
                                _currentDate.month - 1,
                                1,
                              );
                            });
                          },
                          icon: Icon(
                            Icons.arrow_back_ios,
                            size: 18,
                            color: headerTextColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            // Show year picker dialog
                            final year = await showDialog<int>(
                              context: context,
                              builder: (context) => _YearPickerDialog(
                                currentYear: _currentDate.year,
                                isDarkMode: isDarkMode,
                              ),
                            );
                            if (year != null) {
                              setState(() {
                                _currentDate =
                                    DateTime(year, _currentDate.month, 1);
                              });
                            }
                          },
                          child: Text(
                            DateFormat('MMMM yyyy').format(_currentDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final nextMonth = DateTime(
                              _currentDate.year,
                              _currentDate.month + 1,
                              1,
                            );
                            // Don't allow navigating to future months
                            if (!nextMonth.isAfter(DateTime.now())) {
                              setState(() {
                                _currentDate = nextMonth;
                              });
                            }
                          },
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: headerTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Days of week row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((day) => SizedBox(
                                width: 30,
                                child: Text(
                                  day,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: dayTextColor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  // Calendar grid - improved with more space
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: 35, // Simplified for demonstration
                      itemBuilder: (context, index) {
                        // ...existing calendar logic...
                        final firstDayOfMonth =
                            DateTime(_currentDate.year, _currentDate.month, 1);
                        final dayOffset = firstDayOfMonth.weekday % 7;

                        // If before the first day of the month
                        if (index < dayOffset) {
                          return const SizedBox.shrink();
                        }

                        final day = index - dayOffset + 1;

                        // If past the last day of the month
                        if (day >
                            DateUtils.getDaysInMonth(
                                _currentDate.year, _currentDate.month)) {
                          return const SizedBox.shrink();
                        }

                        final date = DateTime(
                            _currentDate.year, _currentDate.month, day);
                        final isSelected =
                            DateUtils.isSameDay(date, widget.selectedDate);
                        final isToday =
                            DateUtils.isSameDay(date, DateTime.now());

                        // Check if date is selectable (not in the future)
                        final isSelectable = !date.isAfter(DateTime.now());

                        return GestureDetector(
                          onTap: isSelectable
                              ? () {
                                  widget.onDateSelected(date);
                                  Navigator.pop(context);
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? ThemeConstants.primaryColor
                                  : (isToday
                                      ? (isDarkMode
                                          ? ThemeConstants.primaryColor
                                              .withOpacity(0.3)
                                          : ThemeConstants.primaryColorLight)
                                      : Colors.transparent),
                            ),
                            child: Center(
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  fontSize: 16, // Increased font size
                                  color: isSelected
                                      ? Colors.white
                                      : (isSelectable
                                          ? (isToday
                                              ? ThemeConstants.primaryColor
                                              : null)
                                          : theme.disabledColor),
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    TextStrings.cancel,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                ),
              ],
            ),
          ),

          // Safe area padding for bottom navigation bar
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// Year picker dialog
class _YearPickerDialog extends StatelessWidget {
  final int currentYear;
  final bool isDarkMode;

  const _YearPickerDialog({
    required this.currentYear,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startYear = 2000;
    final endYear = DateTime.now().year;

    return AlertDialog(
      title: Text(
        'Select Year',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: isDarkMode ? theme.cardColor : Colors.white,
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: endYear - startYear + 1,
          itemBuilder: (context, index) {
            final year = endYear - index;
            final isSelected = year == currentYear;

            return GestureDetector(
              onTap: () {
                Navigator.of(context).pop(year);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeConstants.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? ThemeConstants.primaryColor
                        : (isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade300),
                  ),
                ),
                child: Center(
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
