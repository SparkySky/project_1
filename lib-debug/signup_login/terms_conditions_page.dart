import 'package:flutter/material.dart';
import '../app_theme.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

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
          'Terms & Conditions',
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
              'MYSafeZone Terms and Conditions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using MYSafeZone, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
            ),

            _buildSection(
              '2. Use License',
              'Permission is granted to temporarily download one copy of MYSafeZone per device for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n• Modify or copy the materials\n• Use the materials for any commercial purpose or for any public display\n• Attempt to reverse engineer any software contained in the application\n• Remove any copyright or other proprietary notations from the materials',
            ),

            _buildSection(
              '3. Privacy and Data Protection',
              'MYSafeZone is committed to protecting your privacy and personal information. We collect and process your data in accordance with applicable privacy laws and regulations. Your personal information will be used solely for the purpose of providing emergency services and community support.',
            ),

            _buildSection(
              '4. Emergency Services',
              'MYSafeZone is designed to provide emergency assistance and community support. Users acknowledge that:\n\n• Emergency services are provided on a best-effort basis\n• Response times may vary depending on location and circumstances\n• Users should always contact local emergency services (911) for immediate life-threatening situations\n• The app is not a replacement for professional emergency services',
            ),

            _buildSection(
              '5. User Responsibilities',
              'As a user of MYSafeZone, you agree to:\n\n• Provide accurate and up-to-date information\n• Use the service responsibly and in accordance with local laws\n• Not misuse the emergency features for non-emergency situations\n• Respect other community members and maintain appropriate conduct\n• Report any technical issues or safety concerns promptly',
            ),

            _buildSection(
              '6. Prohibited Uses',
              'You may not use MYSafeZone:\n\n• For any unlawful purpose or to solicit others to perform unlawful acts\n• To violate any international, federal, provincial, or state regulations, rules, laws, or local ordinances\n• To infringe upon or violate our intellectual property rights or the intellectual property rights of others\n• To harass, abuse, insult, harm, defame, slander, disparage, intimidate, or discriminate\n• To submit false or misleading information',
            ),

            _buildSection(
              '7. Content and Media',
              'Users may upload photos, videos, and other media content. By uploading content, you grant MYSafeZone a non-exclusive, royalty-free license to use, display, and distribute such content for the purpose of providing emergency services and community support.',
            ),

            _buildSection(
              '8. Limitation of Liability',
              'In no event shall MYSafeZone, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your use of the service.',
            ),

            _buildSection(
              '9. Indemnification',
              'You agree to defend, indemnify, and hold harmless MYSafeZone and its licensee and licensors, and their employees, contractors, agents, officers and directors, from and against any and all claims, damages, obligations, losses, liabilities, costs or debt, and expenses (including but not limited to attorney\'s fees).',
            ),

            _buildSection(
              '10. Termination',
              'We may terminate or suspend your account and bar access to the service immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever and without limitation, including but not limited to a breach of the Terms.',
            ),

            _buildSection(
              '11. Changes to Terms',
              'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days notice prior to any new terms taking effect.',
            ),

            _buildSection(
              '12. Contact Information',
              'If you have any questions about these Terms and Conditions, please contact us at:\n\nEmail: support@mysafezone.com\nPhone: +1 (555) 123-4567\nAddress: 123 Safety Street, Emergency City, EC 12345',
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
                'By using MYSafeZone, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
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
