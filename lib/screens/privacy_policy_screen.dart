import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF97316),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFF97316),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE5CC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BillMinder Privacy Policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Last updated: November 2024',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Introduction
            const Text(
              'Your privacy is important to us. This Privacy Policy explains how BillMinder collects, uses, and protects your personal information when you use our application.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              '1. Information We Collect',
              '''We collect the following types of information:

Personal Information:
• Email address (for account creation and communication)
• Name (optional, for personalization)
• Password (encrypted and secured)

Bill & Financial Data:
• Bill names, amounts, and due dates
• Payment status and history
• Categories and notes you add

Device Information:
• Device type and operating system
• App version
• Crash logs and performance data''',
            ),

            _buildSection(
              '2. How We Use Your Information',
              '''We use your information to:
• Provide and maintain our service
• Send bill reminders and notifications
• Sync your data across devices
• Improve the App's features and user experience
• Provide customer support
• Analyze usage patterns (anonymously)
• Send important updates about the App''',
            ),

            _buildSection(
              '3. Data Storage & Security',
              '''Your data is stored securely using:
• Firebase Cloud Firestore (Google's secure cloud database)
• Industry-standard encryption (AES-256)
• Secure HTTPS connections
• Authentication via Firebase Auth

We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, or destruction.''',
            ),

            _buildSection('4. Data Sharing', '''We do NOT:
• Sell your personal information to third parties
• Share your financial data with advertisers
• Use your data for targeted advertising

We may share data with:
• Service providers (Firebase, Google) for app functionality
• Legal authorities if required by law
• Business successors in case of merger or acquisition'''),

            _buildSection(
              '5. Third-Party Services',
              '''Our App uses the following third-party services:
• Firebase (Authentication, Database, Analytics)
• Google Cloud Platform (Infrastructure)

These services have their own privacy policies, and we encourage you to review them.''',
            ),

            _buildSection('6. Your Rights', '''You have the right to:
• Access your personal data
• Correct inaccurate data
• Export your data
• Opt-out of non-essential communications
• Withdraw consent at any time

To exercise these rights, contact us or use the App's settings.'''),

            _buildSection('7. Data Retention', '''We retain your data:
• While your account is active
• For a reasonable period after you stop using the App for legal compliance
• Anonymized data may be retained indefinitely for analytics'''),

            _buildSection(
              '8. Children\'s Privacy',
              'Our App is not intended for children under 13 years of age. We do not knowingly collect personal information from children. If you believe we have collected information from a child, please contact us immediately.',
            ),

            _buildSection(
              '9. Cookies & Tracking',
              'Our mobile App does not use cookies. However, our web services may use essential cookies for functionality. We use Firebase Analytics to collect anonymous usage data to improve the App.',
            ),

            _buildSection(
              '10. International Data Transfers',
              'Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.',
            ),

            _buildSection(
              '11. Changes to Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any material changes through the App or via email. Your continued use of the App after such modifications constitutes acceptance of the updated policy.',
            ),

            _buildSection(
              '12. Contact Us',
              'If you have any questions about this Privacy Policy or our data practices, please contact us at:\n\nEmail: privacy@billminder.app',
            ),

            const SizedBox(height: 24),

            // Privacy Commitment
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF3B82F6),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Our Privacy Commitment',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• We never sell your data\n• Your financial information is encrypted\n• You control your data\n• Transparent about our practices',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF3B82F6),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
