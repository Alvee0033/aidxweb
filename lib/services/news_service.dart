import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aidx/models/news_model.dart';
import 'package:aidx/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsService {
  // Singleton pattern
  static final NewsService _instance = NewsService._internal();
  factory NewsService() => _instance;
  NewsService._internal();
  
  final String _baseUrl = 'https://newsapi.org/v2';
  final String _apiKey = AppConstants.newsApiKey;
  
  // Cache keys
  static const String _cacheKeyNews = 'cached_health_news';
  static const String _cacheKeyTimestamp = 'cached_news_timestamp';
  
  // Cache duration (4 hours)
  static const int _cacheDurationInHours = 4;
  
  Future<String> getUserCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get saved country code or default to 'us'
      return prefs.getString(AppConstants.prefCountry) ?? 'us';
    } catch (e) {
      debugPrint('Error getting user country: $e');
      return 'us'; // Default to US
    }
  }
  
  Future<void> setUserCountry(String countryCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefCountry, countryCode);
      
      // Clear cache when country changes to force refresh
      await prefs.remove(_cacheKeyNews);
      await prefs.remove(_cacheKeyTimestamp);
    } catch (e) {
      debugPrint('Error saving user country: $e');
    }
  }
  
  Future<List<NewsArticle>> getHealthNews({String? countryCode, bool forceRefresh = false}) async {
    try {
      // Check if we should use cache
      if (!forceRefresh) {
        final cachedNews = await _getCachedNews();
        if (cachedNews.isNotEmpty) {
          return cachedNews;
        }
      }
      
      // Use provided country code or get from preferences
      final country = countryCode ?? await getUserCountry();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?country=$country&category=health&apiKey=$_apiKey'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"status": "timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'ok' && data['articles'] != null) {
          final articles = data['articles'] as List;
          
          final newsArticles = articles.map((article) {
            return NewsArticle(
              title: article['title'] ?? 'No title',
              description: article['description'],
              url: article['url'],
              imageUrl: article['urlToImage'],
              source: article['source']?['name'] ?? 'Unknown',
              publishedAt: article['publishedAt'],
            );
          }).toList();
          
          // Cache the results
          _cacheNews(newsArticles);
          
          return newsArticles;
        }
      }
      
      // If we get here, something went wrong
      debugPrint('Error fetching news: ${response.statusCode} - ${response.body}');
      
      // Try to get cached news as fallback
      final cachedNews = await _getCachedNews(ignoreExpiry: true);
      if (cachedNews.isNotEmpty) {
        return cachedNews;
      }
      
      return [];
    } catch (e) {
      debugPrint('Exception fetching news: $e');
      
      // Try to get cached news as fallback
      final cachedNews = await _getCachedNews(ignoreExpiry: true);
      if (cachedNews.isNotEmpty) {
        return cachedNews;
      }
      
      return [];
    }
  }
  
  Future<void> _cacheNews(List<NewsArticle> news) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert news articles to JSON
      final newsJson = news.map((article) => article.toMap()).toList();
      
      // Save to cache
      await prefs.setString(_cacheKeyNews, json.encode(newsJson));
      await prefs.setInt(_cacheKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching news: $e');
    }
  }
  
  Future<List<NewsArticle>> _getCachedNews({bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we have cached news
      final cachedNewsJson = prefs.getString(_cacheKeyNews);
      if (cachedNewsJson == null) {
        return [];
      }
      
      // Check if cache is expired (unless we're ignoring expiry)
      if (!ignoreExpiry) {
        final timestamp = prefs.getInt(_cacheKeyTimestamp) ?? 0;
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        
        // Check if cache is older than cache duration
        if (now.difference(cacheTime).inHours > _cacheDurationInHours) {
          return [];
        }
      }
      
      // Parse cached news
      final newsJsonList = json.decode(cachedNewsJson) as List;
      return newsJsonList.map((item) => NewsArticle.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting cached news: $e');
      return [];
    }
  }
  
  Future<List<NewsArticle>> searchHealthNews(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/everything?q=$query AND health&sortBy=relevancy&apiKey=$_apiKey'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"status": "timeout"}', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'ok' && data['articles'] != null) {
          final articles = data['articles'] as List;
          
          return articles.map((article) {
            return NewsArticle(
              title: article['title'] ?? 'No title',
              description: article['description'],
              url: article['url'],
              imageUrl: article['urlToImage'],
              source: article['source']?['name'] ?? 'Unknown',
              publishedAt: article['publishedAt'],
            );
          }).toList();
        }
      }
      
      // If we get here, something went wrong
      debugPrint('Error searching news: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Exception searching news: $e');
      return [];
    }
  }
} 