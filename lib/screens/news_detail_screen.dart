import 'package:flutter/material.dart';
import 'package:aidx/models/news_model.dart';
import 'package:aidx/utils/theme.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aidx/services/notification_service.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsArticle article;
  
  const NewsDetailScreen({
    super.key,
    required this.article,
  });

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  Future<void> _openArticleUrl(BuildContext context) async {
    if (article.url != null && article.url!.isNotEmpty) {
      final Uri url = Uri.parse(article.url!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open article')),
          );
        }
      }
    }
  }

  Future<void> _shareArticle() async {
    if (article.url != null && article.url!.isNotEmpty) {
      final String shareText = '${article.title}\n\n${article.url}';
      await Share.share(shareText, subject: 'Check out this health news article');
    }
  }

  void _scheduleReminder(BuildContext context) {
    final notificationService = NotificationService();
    
    // Schedule a notification for 1 hour later
    final DateTime reminderTime = DateTime.now().add(const Duration(hours: 1));
    
    notificationService.scheduleNotification(
      title: 'Article Reminder',
      body: 'Remember to read: ${article.title}',
      scheduledTime: reminderTime,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder set for ${DateFormat('h:mm a').format(reminderTime)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.share2),
            onPressed: _shareArticle,
            tooltip: 'Share article',
          ),
          IconButton(
            icon: const Icon(FeatherIcons.bell),
            onPressed: () => _scheduleReminder(context),
            tooltip: 'Set reminder',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              Hero(
                tag: 'news_image',
                child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 50,
                            ),
                          );
                        },
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 200,
                color: AppTheme.primaryColor.withOpacity(0.8),
              ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Source and date
                  Row(
                    children: [
                      if (article.source != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            article.source!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      if (article.source != null && article.publishedAt != null)
                        const SizedBox(width: 8),
                      if (article.publishedAt != null)
                        Text(
                          _formatDate(article.publishedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Description
                  if (article.description != null && article.description!.isNotEmpty)
                    Text(
                      article.description!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  // Read more button
                  if (article.url != null && article.url!.isNotEmpty)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _openArticleUrl(context),
                        icon: const Icon(FeatherIcons.externalLink),
                        label: const Text('Read Full Article'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 