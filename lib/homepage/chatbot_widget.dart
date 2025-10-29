import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../tutorial/chatbot_tutorial.dart';
import '../repository/incident_repository.dart';

class ChatbotWidget extends StatefulWidget {
  final bool isCollapsed;

  const ChatbotWidget({super.key, this.isCollapsed = false});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      bottom: widget.isCollapsed ? null : 20,
      top: widget.isCollapsed ? 88 : null, // Below filter button (16 + 56 + 16)
      right: 16,
      child: FloatingActionButton(
        heroTag: "chatbot_fab",
        onPressed: _openChatbot,
        backgroundColor: AppTheme.primaryOrange,
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
      ),
    );
  }
}

// Chatbot Page with API Integration
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _incidentRepository = IncidentRepository();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isLoading = false;
  String? _incidentSummary;
  final List<Map<String, String>> _chatHistory = []; // For Gemini context

  List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    _initializeChatbot();

    // Show tutorial after page loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await ChatbotTutorialManager.showTutorialIfNeeded(
          context,
          pageScrollController: _scrollController,
          onSendMessage: _sendTutorialMessage,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _incidentRepository.closeZone();
    // Clear chat history when leaving
    _chatHistory.clear();

    super.dispose();
  }

  // Helper method to send messages from tutorial
  void _sendTutorialMessage(String message) async {
    setState(() {
      messages.add(
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final aiResponse = await _getAIResponseFromAPI(message);

    setState(() {
      messages.add(
        ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()),
      );
      _isLoading = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initializeChatbot() async {
    // Fetch recent incidents and create summary
    await _fetchRecentIncidents();

    // Add welcome message with incident summary
    setState(() {
      messages.add(
        ChatMessage(
          text: _getWelcomeMessage(),
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  String _getWelcomeMessage() {
    String welcome = "Hello! I'm your MYSafeZone Assistant. 🛡️\n\n";

    if (_incidentSummary != null && _incidentSummary!.isNotEmpty) {
      welcome += _incidentSummary!;
      welcome += "\n\nFeel free to ask me any safety-related questions!";
    } else {
      welcome += "How can I help you stay safe today?";
    }

    return welcome;
  }

  Future<void> _fetchRecentIncidents() async {
    try {
      await _incidentRepository.openZone();

      // Get all incidents from last 3 days
      final allIncidents = await _incidentRepository.getAllIncidents();
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final recentIncidents = allIncidents
          .where((incident) => incident.datetime.isAfter(threeDaysAgo))
          .toList();

      if (recentIncidents.isEmpty) {
        _incidentSummary =
            "📊 No incidents reported in the last 3 days. Your area has been safe!";
        await _incidentRepository.closeZone();
        return;
      }

      // Group by status
      final activeCount = recentIncidents
          .where((i) => i.status == 'active')
          .length;
      final endedCount = recentIncidents
          .where((i) => i.status == 'endedByBtn')
          .length;
      final resolvedCount = recentIncidents
          .where((i) => i.status == 'resolved')
          .length;

      // Group by type
      final threatCount = recentIncidents
          .where((i) => i.incidentType == 'threat')
          .length;
      final generalCount = recentIncidents
          .where((i) => i.incidentType == 'general')
          .length;

      // Build summary (plain text, no markdown)
      String summary = "📊 Recent Incidents (Last 3 Days)\n";
      summary +=
          "Total: ${recentIncidents.length} incident${recentIncidents.length > 1 ? 's' : ''}\n\n";

      if (activeCount > 0) summary += "• 🔴 Active: $activeCount\n";
      if (endedCount > 0) summary += "• 🟢 Ended: $endedCount\n";
      if (resolvedCount > 0) summary += "• ⚪ Resolved: $resolvedCount\n";

      summary += "\nBy Type:\n";
      if (threatCount > 0) summary += "• ⚠️ Threats: $threatCount\n";
      if (generalCount > 0) summary += "• 📍 General: $generalCount\n";

      // Get sample descriptions (first 3)
      if (recentIncidents.isNotEmpty) {
        summary += "\nRecent Events:\n";
        for (
          int i = 0;
          i < (recentIncidents.length > 3 ? 3 : recentIncidents.length);
          i++
        ) {
          final incident = recentIncidents[i];
          String desc = incident.desc;
          if (desc.contains('\n---\n')) {
            desc = desc.split('\n---\n')[0]; // Get title only
          }
          if (desc.length > 60) desc = '${desc.substring(0, 60)}...';
          summary += "• $desc\n";
        }
      }

      _incidentSummary = summary;
      await _incidentRepository.closeZone();
    } catch (e) {

      _incidentSummary = null;
    }
  }

  Future<String> _getAIResponseFromAPI(String userMessage) async {
    try {
      // Get API key
      String? customApiKey = await _secureStorage.read(key: 'gemini_api_key');
      if (customApiKey == null) {
        final prefs = await SharedPreferences.getInstance();
        customApiKey = prefs.getString('gemini_api_key');
      }
      final apiKey = customApiKey ?? dotenv.env['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        return _getFallbackResponse(userMessage);
      }

      // Add user message to chat history
      _chatHistory.add({'role': 'user', 'parts': userMessage});

      // Build system instruction with incident context
      final systemInstruction = _buildSystemInstruction();

      // Call Gemini 2.0 Flash API
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': _chatHistory
              .map(
                (msg) => {
                  'role': msg['role'] == 'user' ? 'user' : 'model',
                  'parts': [
                    {'text': msg['parts']},
                  ],
                },
              )
              .toList(),
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction},
            ],
          },
          'generationConfig': {
            'temperature': 0.7,
            'topP': 0.95,
            'topK': 40,
            'maxOutputTokens': 1024,
            'responseMimeType': 'text/plain',
          },
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_NONE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_NONE',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Clean response with regex for Gemini 2.0 Flash
        final cleanedResponse = _cleanGeminiResponse(aiResponse);

        // Add AI response to chat history
        _chatHistory.add({'role': 'model', 'parts': cleanedResponse});

        return cleanedResponse;
      } else {
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {

      return _getFallbackResponse(userMessage);
    }
  }

  String _buildSystemInstruction() {
    String instruction =
        """You are the MYSafeZone Assistant, a helpful and empathetic AI assistant for a safety and incident reporting app called MYSafeZone.

YOUR ROLE:
- Help users understand safety in their area
- Provide actionable safety recommendations
- Summarize recent incident patterns
- Answer questions about app features
- Offer support and guidance during emergencies
- Provide emergency contact information

📊 RECENT INCIDENT DATA (LAST 3 DAYS):
${_incidentSummary ?? 'No recent incident data available.'}

============================================
EMERGENCY CONTACTS:
============================================
🚨 For ALL emergencies, call 999
• Police Emergency: 999
• Ambulance: 999
• Fire Department: 999 or 994

============================================
INSTRUCTIONS:
============================================

1. FOR EMERGENCIES:
   - Life-threatening situations: Direct to 999 immediately
   - Medical emergencies: 999 for ambulance
   - Fire: 999 or 994
   - Police assistance: 999

2. RESPONSE FORMAT:
   - Be concise but informative (under 250 words)
   - Use emojis appropriately for friendliness
   - When discussing incidents, focus on awareness, not fear
   - Format phone numbers clearly (they are clickable!)
   - Use "EMERGENCY CONTACTS:" for emergency numbers
   - Use "SAFETY TIPS:" for safety advice

3. FORMATTING RULES:
   - Use UPPERCASE for section headers (e.g., "EMERGENCY CONTACTS:")
   - Do NOT use markdown (no **, *, _, ~~, #)
   - Use emojis and bullet points (•) for lists
   - Phone numbers will be automatically made clickable

SAFETY TIPS TO SHARE WHEN RELEVANT:
- Stay aware of surroundings
- Use the buddy system at night
- Keep phone charged
- Share location with trusted contacts
- Report suspicious activity promptly
- Avoid isolated areas after dark
- Trust your instincts
- Call 999 in emergencies

Remember: Your goal is to help users feel safer and more informed, not anxious. Always provide 999 as the primary emergency contact.""";

    return instruction;
  }

  String _cleanGeminiResponse(String response) {
    String cleaned = response;

    // Remove code blocks first (```...```) - unlikely but just in case
    cleaned = cleaned.replaceAll(
      RegExp(r'```[\s\S]*?```', multiLine: true, dotAll: true),
      '',
    );

    // Remove inline code backticks (`...`)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // Remove markdown formatting (order matters - longest patterns first)
    // Bold+Italic (*** or ___)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*\*([\s\S]+?)\*\*\*', multiLine: true),
      (match) {
        return match.group(1) ?? '';
      },
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'___([\s\S]+?)___', multiLine: true),
      (match) => match.group(1) ?? '',
    );

    // Bold (** or __)
    int boldCount = 0;
    cleaned = cleaned.replaceAllMapped(RegExp(r'\*\*([^\*]+?)\*\*'), (match) {
      boldCount++;
      return match.group(1) ?? '';
    });


    cleaned = cleaned.replaceAllMapped(
      RegExp(r'__([^_]+?)__'),
      (match) => match.group(1) ?? '',
    );

    // Italic (* or _) - match non-greedily, avoid breaking bullet points
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*([^\*\n]+?)\*'),
      (match) => match.group(1) ?? '',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'_([^_\n]+?)_'),
      (match) => match.group(1) ?? '',
    );

    // Strikethrough (~~...~~)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'~~([^\~]+?)~~'),
      (match) => match.group(1) ?? '',
    );

    // Remove markdown headers (# at start of line) but keep the text
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Convert links [text](url) to just the text
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // Normalize bullet points - convert markdown bullets (-, *, +) to •
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      '• ',
    );

    // Remove extra newlines (more than 2 consecutive newlines)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove extra spaces (more than 2 consecutive spaces)
    cleaned = cleaned.replaceAll(RegExp(r' {3,}'), '  ');

    // Trim leading/trailing whitespace
    cleaned = cleaned.trim();
    return cleaned;
  }

  String _getFallbackResponse(String userMessage) {
    String lowerMessage = userMessage.toLowerCase();

    // Handle police/emergency contact queries
    if (lowerMessage.contains('police') ||
        lowerMessage.contains('station') ||
        lowerMessage.contains('contact') ||
        lowerMessage.contains('emergency') ||
        lowerMessage.contains('help')) {
      return "🚨 EMERGENCY CONTACTS:\n\n"
          "For ALL emergencies, call:\n"
          "• Police: 999\n"
          "• Ambulance: 999\n"
          "• Fire Department: 999 or 994\n\n"
          "These numbers are available 24/7 across Malaysia.";
    }

    // Handle incident/report queries
    if (lowerMessage.contains('incident') || lowerMessage.contains('report')) {
      return "📍 TO REPORT AN INCIDENT:\n\n"
          "• Tap the map on the Home screen\n"
          "• Use the Community section\n"
          "• Provide detailed location and description\n\n"
          "🚨 For emergencies, call 999 immediately!";
    }

    // Handle safety tips queries
    if (lowerMessage.contains('safe') ||
        lowerMessage.contains('aware') ||
        lowerMessage.contains('tips')) {
      String tips = "SAFETY TIPS:\n\n";
      tips += "• Stay aware of your surroundings\n";
      tips += "• Check the incident map regularly\n";
      tips += "• Report suspicious activity\n";
      tips += "• Keep phone charged\n";
      tips += "• Share location with trusted contacts\n";
      tips += "• Avoid isolated areas after dark\n";
      tips += "• Trust your instincts\n";
      tips += "• Call 999 in emergencies";

      if (_incidentSummary != null && _incidentSummary!.isNotEmpty) {
        tips += "\n\n$_incidentSummary";
      }
      return tips;
    }

    // Handle summary/recent incidents queries
    if (lowerMessage.contains('summary') ||
        lowerMessage.contains('recent') ||
        lowerMessage.contains('incident')) {
      return _incidentSummary ??
          "📊 No recent incident data available.\n\nYour area has been safe!";
    }

    // Default response
    return "I'm here to help with safety information! Try asking about:\n\n"
        "• Recent incidents\n"
        "• Safety tips\n"
        "• Emergency contacts (999)\n"
        "• How to report incidents";
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text;

    setState(() {
      messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final aiResponse = await _getAIResponseFromAPI(userMessage);

    setState(() {
      messages.add(
        ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()),
      );
      _isLoading = false;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow keyboard resize
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: RepaintBoundary(
          child: AppBar(
            backgroundColor: AppTheme.primaryOrange,
            elevation: 4,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            title: const Row(
              children: [
                Icon(Icons.android, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MYSafeZone Assistant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Powered by Gemini 2.0 Flash',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (_isLoading ? 1 : 0),
                cacheExtent:
                    500, // Pre-render offscreen items for smoother scrolling
                addAutomaticKeepAlives: false, // Reduce memory usage
                addRepaintBoundaries: true, // Isolate each item's repaints
                itemBuilder: (context, index) {
                  if (index == messages.length && _isLoading) {
                    return _buildLoadingIndicator();
                  }
                  return _buildMessageBubble(messages[index]);
                },
              ),
            ),
          ),
          RepaintBoundary(child: _buildMessageInput()),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryOrange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.primaryOrange : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
            bottomLeft: message.isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            message.isUser
                ? Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  )
                : _buildClickableText(message.text, Colors.grey[800]!),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: message.isUser ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableText(String text, Color textColor) {
    final List<TextSpan> spans = [];

    // Process text line by line to handle multiple patterns
    final lines = text.split('\n');
    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];

      // Check if line starts with a section header (UPPERCASE words followed by colon)
      final headerMatch = RegExp(r'^([A-Z][A-Z\s]{2,}:)').firstMatch(line);

      if (headerMatch != null) {
        // Bold section header
        final header = headerMatch.group(1)!;
        final restOfLine = line.substring(headerMatch.end);

        spans.add(
          TextSpan(
            text: header,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              height: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        // Process rest of line for phone numbers
        _addTextWithPhoneNumbers(restOfLine, spans, textColor);
      } else {
        // Process line for phone numbers
        _addTextWithPhoneNumbers(line, spans, textColor);
      }

      // Add newline except for last line
      if (lineIdx < lines.length - 1) {
        spans.add(
          TextSpan(
            text: '\n',
            style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        children: spans.isNotEmpty
            ? spans
            : [
                TextSpan(
                  text: text,
                  style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
                ),
              ],
      ),
    );
  }

  void _addTextWithPhoneNumbers(
    String text,
    List<TextSpan> spans,
    Color textColor,
  ) {
    final phoneRegex = RegExp(
      r'(\b\d{3}\b|\b\d{2,3}-\d{7,8}\b|\b\d{4}-\d{3}-\d{3,4}\b)',
    );

    int lastMatchEnd = 0;

    for (final match in phoneRegex.allMatches(text)) {
      // Add text before the phone number
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
          ),
        );
      }

      // Add the clickable phone number
      final phoneNumber = match.group(0)!;
      spans.add(
        TextSpan(
          text: phoneNumber,
          style: TextStyle(
            fontSize: 15,
            color: Colors.blue[700],
            height: 1.4,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _makePhoneCall(phoneNumber);
            },
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add remaining text after the last phone number
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Remove any spaces or hyphens from the number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch phone app for $phoneNumber'),
            ),
          );
        }
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isLoading,
              autocorrect: false, // Disable autocorrect for performance
              enableSuggestions: false, // Disable suggestions for performance
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: _isLoading
                    ? 'Waiting for response...'
                    : 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: _isLoading ? Colors.grey[100] : Colors.grey[50],
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _isLoading ? null : _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey[400] : AppTheme.primaryOrange,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
