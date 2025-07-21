import 'package:flutter/material.dart';
import 'package:aidx/utils/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;

  const NewsCard({
    super.key,
    required this.article,
  });

  Future<void> _openArticle() async {
    if (article['url'] != null && article['url'].isNotEmpty) {
      final Uri url = Uri.parse(article['url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openArticle,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgGlassMedium,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article image
            if (article['imageUrl'] != null && article['imageUrl'].isNotEmpty)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: article['imageUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.error),
                    ),
                  ),
                ),
              ),
            
            // Article content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article['title'] ?? 'No title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  if (article['description'] != null && article['description'].isNotEmpty)
                    Text(
                      article['description'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  
                  // Source and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article['source'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDate(article['publishedAt'] ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
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