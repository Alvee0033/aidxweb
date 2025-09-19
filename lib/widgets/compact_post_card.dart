import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../models/community_support_model.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';

class CompactPostCard extends StatelessWidget {
  final CommunityPostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final bool isLiked;
  final bool showComments;
  final VoidCallback onToggleComments;
  final List<CommunityCommentModel> comments;
  final TextEditingController commentController;
  final VoidCallback onAddComment;

  const CompactPostCard({
    Key? key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onDelete,
    required this.isLiked,
    required this.showComments,
    required this.onToggleComments,
    required this.comments,
    required this.commentController,
    required this.onAddComment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      padding: Responsive.getPadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.13),
            AppTheme.bgGlassMedium.withOpacity(0.18),
          ],
        ),
        borderRadius: Responsive.getBorderRadius(context),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isMobile),
          const SizedBox(height: 8),
          _buildContent(context, isMobile),
          const SizedBox(height: 8),
          _buildActions(context, isMobile),
          if (showComments) ...[
            const SizedBox(height: 8),
            _buildCommentsSection(context, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      children: [
        CircleAvatar(
          radius: Responsive.getAvatarRadius(context),
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            post.userName[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: Responsive.getFontSize(context, mobile: 12, tablet: 14, desktop: 16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.userName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.getFontSize(context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              Text(
                post.userLocation,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: Responsive.getFontSize(context, mobile: 11, tablet: 12, desktop: 14),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            FeatherIcons.moreVertical, 
            color: Colors.white, 
            size: Responsive.getIconSize(context, mobile: 16, tablet: 18, desktop: 20)
          ),
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.content,
          style: TextStyle(
            color: Colors.white, 
            fontSize: Responsive.getFontSize(context, mobile: 14, tablet: 16, desktop: 18)
          ),
        ),
        if (post.imageUrl != null || post.imageBase64 != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: Responsive.getBorderRadius(context),
            child: _buildImage(context),
          ),
        ],
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    final double height = Responsive.getImageHeight(context);
    if (post.imageBase64 != null && post.imageBase64!.isNotEmpty) {
      final String dataUrl = post.imageBase64!.startsWith('data:')
          ? post.imageBase64!
          : 'data:image/png;base64,${post.imageBase64!}';
      return Image.network(
        dataUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _imageFallback(context),
      );
    }
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return Image.network(
        post.imageUrl!,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _imageFallback(context),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _imageFallback(BuildContext context) {
    return Container(
      height: Responsive.getImageHeight(context),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: Responsive.getBorderRadius(context),
      ),
      child: Icon(
        FeatherIcons.image,
        color: Colors.white,
        size: Responsive.getIconSize(context, mobile: 32, tablet: 40, desktop: 48),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isMobile) {
    return Row(
      children: [
        _buildActionButton(
          context: context,
          icon: FeatherIcons.heart,
          label: '${post.likes}',
          onTap: onLike,
          isActive: isLiked,
        ),
        SizedBox(width: Responsive.getSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
        _buildActionButton(
          context: context,
          icon: FeatherIcons.messageCircle,
          label: '${post.comments}',
          onTap: onToggleComments,
        ),
        SizedBox(width: Responsive.getSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
        _buildActionButton(
          context: context,
          icon: FeatherIcons.share,
          label: '${post.shares}',
          onTap: onShare,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.accentColor : Colors.white.withOpacity(0.7),
            size: Responsive.getIconSize(context, mobile: 14, tablet: 16, desktop: 18),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.accentColor : Colors.white.withOpacity(0.7),
              fontSize: Responsive.getFontSize(context, mobile: 11, tablet: 12, desktop: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, bool isMobile) {
    return Column(
      children: [
        ...comments.map((comment) => _buildCommentItem(context, comment, isMobile)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: Responsive.getFontSize(context, mobile: 12, tablet: 14, desktop: 16)
                ),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(
                    color: Colors.white70, 
                    fontSize: Responsive.getFontSize(context, mobile: 12, tablet: 14, desktop: 16)
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Responsive.getSpacing(context, mobile: 8, tablet: 12, desktop: 16),
                    vertical: Responsive.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onAddComment,
              icon: Icon(
                FeatherIcons.send, 
                color: Colors.white, 
                size: Responsive.getIconSize(context, mobile: 16, tablet: 18, desktop: 20)
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentItem(BuildContext context, CommunityCommentModel comment, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.getSpacing(context, mobile: 6, tablet: 8, desktop: 10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: Responsive.getAvatarRadius(context, mobile: 10, tablet: 12, desktop: 14),
            backgroundColor: AppTheme.accentColor,
            child: Text(
              comment.userName[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: Responsive.getFontSize(context, mobile: 9, tablet: 10, desktop: 12),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: Responsive.getSpacing(context, mobile: 6, tablet: 8, desktop: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.getFontSize(context, mobile: 11, tablet: 12, desktop: 14),
                  ),
                ),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.getFontSize(context, mobile: 11, tablet: 12, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 