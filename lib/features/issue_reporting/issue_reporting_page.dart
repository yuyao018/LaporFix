import 'package:flutter/material.dart';

import 'package:group2_urbanfix/features/issue_reporting/viewmodels/issue_reporting_view_model.dart';

import 'package:group2_urbanfix/theme/app_theme.dart';

import 'package:group2_urbanfix/widgets/function_appbar.dart';

import '../issue_reporting/issue_reporting_map.dart';

class IssueReportingPage extends StatefulWidget {
  const IssueReportingPage({super.key});

  VoidCallback? get onBack => null;

  @override
  State<IssueReportingPage> createState() => _IssueReportingPageState();
}

class _IssueReportingPageState extends State<IssueReportingPage> {
  late final IssueReportingViewModel viewModel;

  @override
  void initState() {
    super.initState();

    viewModel = IssueReportingViewModel();
  }

  @override
  Widget build(BuildContext context) {
    bool isOtherSelected = viewModel.report.category == 'Other';

    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: FunctionAppBar(title: 'Create Report', onBack: widget.onBack),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.functionBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Photo Uploader
                              GestureDetector(
                                onTap: () async {
                                  if (viewModel.report.image == null) {
                                    await viewModel.pickImage();

                                    setState(() {});
                                  }
                                },

                                child: Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E4E7),

                                    borderRadius: BorderRadius.circular(16),
                                  ),

                                  child: viewModel.report.image == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,

                                          children: [
                                            SizedBox(
                                              width: 100,
                                              height: 80,
                                              child: FittedBox(
                                                fit: BoxFit.fill,
                                                child: const Icon(
                                                  Icons.camera_alt_outlined,
                                                  color: Color(0xFF8B8E93),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 12),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 50,
                                                  ),

                                              decoration: BoxDecoration(
                                                color: AppTheme.accentBlue,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),

                                              child: Text(
                                                'Add Photo',
                                                style: AppTheme
                                                    .appTextTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Stack(
                                          children: [
                                            // Display selected image
                                            Positioned.fill(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.file(
                                                  viewModel.report.image!,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),

                                            // Delete image button (top-right corner)
                                            Positioned(
                                              top: 12,
                                              right: 12,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    viewModel.report.image =
                                                        null;
                                                  });
                                                },

                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),

                                                    shape: BoxShape.circle,
                                                  ),

                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Edit image button
                                            Positioned(
                                              bottom: 31,
                                              left: 0,
                                              right: 0,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    await viewModel.pickImage();

                                                    setState(() {});
                                                  },

                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 50,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppTheme.accentBlue,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(alpha: 0.2),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    child: Text(
                                                      'Edit Photo',
                                                      style: AppTheme
                                                          .appTextTheme
                                                          .labelLarge
                                                          ?.copyWith(
                                                            fontSize: 16,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Category Section
                              const Text(
                                'Select Category',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF1F3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12),
                                ),

                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value:
                                        (viewModel.categories.contains(
                                          viewModel.report.category,
                                        ))
                                        ? viewModel.report.category
                                        : null,

                                    hint: const Text(
                                      'Select Category',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),

                                    isExpanded: true,

                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                      size: 28,
                                    ),

                                    items: viewModel.categories.map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),

                                    onChanged: (e) {
                                      viewModel.report.category = e ?? '';

                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),

                              // Show custom category input if "Other" is selected
                              if (isOtherSelected) ...[
                                const SizedBox(height: 12),

                                TextField(
                                  style: const TextStyle(fontSize: 16),
                                  onChanged: (value) =>
                                      viewModel.report.category = value,
                                  maxLength: 12,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your category',
                                    hintStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),

                                    filled: true,
                                    fillColor: const Color(0xFFEBF1F3),
                                    isDense: true,

                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Description
                              const Text(
                                'Add Description',

                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Description Input Field
                              SizedBox(
                                height: 280,
                                child: TextField(
                                  style: const TextStyle(fontSize: 16),
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (value) {
                                    viewModel.report.description = value;

                                    setState(() {}); // Refresh UI
                                  },

                                  decoration: InputDecoration(
                                    hintText: 'Add a description text...',
                                    hintStyle: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),

                                    filled: true,
                                    fillColor: const Color(0xFFEBF1F3),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB4B4B4),
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Next Button
                              SizedBox(
                                width: 350,
                                height: 55,

                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: viewModel.validateStepOne()
                                        ? AppTheme.accentBlue
                                        : Colors.grey.shade400,

                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),

                                  onPressed: () async {
                                    // Prevent navigation if required fields are missing

                                    if (!viewModel.validateStepOne()) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please upload a photo, select a category, and add a description.',
                                          ),

                                          backgroundColor: Colors.redAccent,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );

                                      return; // Prevent navigation
                                    }

                                    // Capture navigator before async gap
                                    final navigator = Navigator.of(context);

                                    // Show loading indicator while fetching location
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );

                                    await viewModel.getCurrentLocation();

                                    if (!mounted) return;
                                    navigator.pop();
                                    navigator.push(
                                      MaterialPageRoute(
                                        builder: (_) => IssueReportingMap(
                                          viewModel: viewModel,
                                        ),
                                      ),
                                    );
                                  },

                                  child: Text(
                                    'Next',

                                    style: AppTheme.appTextTheme.labelLarge
                                        ?.copyWith(
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
