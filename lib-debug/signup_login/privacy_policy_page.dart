import 'package:flutter/material.dart';
import '../app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryOrange),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppTheme.primaryOrange,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MYSafeZone Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. Information We Collect',
              'We collect information you provide directly to us, such as when you create an account, use our emergency services, or contact us for support. This may include:\n\n• Personal information (name, email, phone number)\n• Location data (for emergency services)\n• Media content (photos, videos for incident reporting)\n• Device information and usage data',
            ),

            _buildSection(
              '2. How We Use Your Information',
              'We use the information we collect to:\n\n• Provide emergency services and community support\n• Verify your identity and maintain account security\n• Send important notifications about safety alerts\n• Improve our services and user experience\n• Comply with legal obligations and emergency protocols',
            ),

            _buildSection(
              '3. Information Sharing',
              'We may share your information in the following circumstances:\n\n• With emergency services when you request help\n• With law enforcement when required by law\n• With your consent for specific purposes\n• To protect the safety and security of our users\n• In case of a business transfer or merger',
            ),

            _buildSection(
              '4. Data Security',
              'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.',
            ),

            _buildSection(
              '5. Location Data',
              'MYSafeZone collects location data to provide emergency services. This data is:\n\n• Used only for safety and emergency purposes\n• Stored securely and encrypted\n• Shared only with authorized emergency responders\n• Retained only as long as necessary for safety purposes',
            ),

            _buildSection(
              '6. Media Content',
              'Photos and videos you upload are:\n\n• Used for incident documentation and emergency response\n• Stored securely with encryption\n• Shared only with relevant emergency services\n• Subject to the same privacy protections as other personal data',
            ),

            _buildSection(
              '7. Your Rights',
              'You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Opt out of non-essential communications\n• Request data portability\n• Withdraw consent for data processing',
            ),

            _buildSection(
              '8. Data Retention',
              'We retain your information for as long as necessary to provide our services and comply with legal obligations. Emergency data may be retained longer for safety and legal compliance purposes.',
            ),

            _buildSection(
              '9. Children\'s Privacy',
              'MYSafeZone is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected such information, we will take steps to delete it.',
            ),

            _buildSection(
              '10. Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.',
            ),

            _buildSection(
              '11. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@mysafezone.com\nPhone: +1 (555) 123-4567\nAddress: 123 Safety Street, Emergency City, EC 12345',
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Text(
                'By using MYSafeZone, you acknowledge that you have read and understood this Privacy Policy.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
