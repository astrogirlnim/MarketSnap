import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_typography.dart';
import '../../../../shared/presentation/widgets/market_snap_components.dart';
import '../../../../core/models/faq_vector.dart';
import '../../../../core/models/rag_feedback.dart';
import '../../../auth/application/auth_service.dart';

/// Vendor Knowledge Base Management Screen
/// Allows vendors to manage their FAQ content and view analytics
class VendorKnowledgeBaseScreen extends StatefulWidget {
  const VendorKnowledgeBaseScreen({super.key});

  @override
  State<VendorKnowledgeBaseScreen> createState() => _VendorKnowledgeBaseScreenState();
}

class _VendorKnowledgeBaseScreenState extends State<VendorKnowledgeBaseScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentVendorId;
  bool _isLoading = true;
  List<FAQVector> _faqs = [];
  Map<String, List<RAGFeedback>> _analytics = {};

  @override
  void initState() {
    super.initState();
    developer.log('[VendorKnowledgeBaseScreen] initState called');
    _tabController = TabController(length: 2, vsync: this);
    _initializeVendor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize vendor data and load FAQs
  Future<void> _initializeVendor() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        developer.log('[VendorKnowledgeBaseScreen] No authenticated user found');
        return;
      }
      
      _currentVendorId = user.uid;
      developer.log('[VendorKnowledgeBaseScreen] Loading knowledge base for vendor: $_currentVendorId');
      
      await _loadFAQs();
      await _loadAnalytics();
    } catch (e) {
      developer.log('[VendorKnowledgeBaseScreen] Error initializing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Load vendor's FAQ vectors from Firestore
  Future<void> _loadFAQs() async {
    if (_currentVendorId == null) return;
    
    try {
      developer.log('[VendorKnowledgeBaseScreen] Loading FAQs for vendor: $_currentVendorId');
      
      final snapshot = await _firestore
          .collection('faqVectors')
          .where('vendorId', isEqualTo: _currentVendorId)
          .orderBy('updatedAt', descending: true)
          .get();
      
      final faqs = snapshot.docs.map((doc) => FAQVector.fromFirestore(doc)).toList();
      
      setState(() {
        _faqs = faqs;
      });
      
      developer.log('[VendorKnowledgeBaseScreen] Loaded ${faqs.length} FAQs');
    } catch (e) {
      developer.log('[VendorKnowledgeBaseScreen] Error loading FAQs: $e');
    }
  }

  /// Load analytics data for vendor's content
  Future<void> _loadAnalytics() async {
    if (_currentVendorId == null) return;
    
    try {
      developer.log('[VendorKnowledgeBaseScreen] Loading analytics for vendor: $_currentVendorId');
      
      final snapshot = await _firestore
          .collection('ragFeedback')
          .where('vendorId', isEqualTo: _currentVendorId)
          .where('contentType', isEqualTo: 'faq')
          .orderBy('createdAt', descending: true)
          .limit(100) // Limit to recent feedback
          .get();
      
      final analytics = <String, List<RAGFeedback>>{};
      
      for (final doc in snapshot.docs) {
        final feedback = RAGFeedback.fromFirestore(doc);
        final contentId = feedback.contentId;
        
        if (!analytics.containsKey(contentId)) {
          analytics[contentId] = [];
        }
        analytics[contentId]!.add(feedback);
      }
      
      setState(() {
        _analytics = analytics;
      });
      
      developer.log('[VendorKnowledgeBaseScreen] Loaded analytics for ${analytics.length} FAQ items');
    } catch (e) {
      developer.log('[VendorKnowledgeBaseScreen] Error loading analytics: $e');
    }
  }

  /// Show dialog for creating/editing FAQ
  Future<void> _showFAQDialog({FAQVector? existingFAQ}) async {
    final questionController = TextEditingController(text: existingFAQ?.question ?? '');
    final answerController = TextEditingController(text: existingFAQ?.answer ?? '');
    final categoryController = TextEditingController(text: existingFAQ?.category ?? 'general');
    final keywordsController = TextEditingController(
      text: existingFAQ?.keywords.join(', ') ?? ''
    );
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.eggshell,
        title: Text(
          existingFAQ == null ? 'Add FAQ' : 'Edit FAQ',
          style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question field
              MarketSnapTextField(
                labelText: 'Question',
                hintText: 'What question do customers often ask?',
                controller: questionController,
                prefixIcon: Icons.help_outline,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Answer field
              MarketSnapTextField(
                labelText: 'Answer',
                hintText: 'Provide a helpful, detailed answer',
                controller: answerController,
                prefixIcon: Icons.chat_bubble_outline,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Category field
              MarketSnapTextField(
                labelText: 'Category',
                hintText: 'e.g., produce, hours, payment',
                controller: categoryController,
                prefixIcon: Icons.category,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Keywords field
              MarketSnapTextField(
                labelText: 'Keywords (comma separated)',
                hintText: 'tomatoes, fresh, organic, local',
                controller: keywordsController,
                prefixIcon: Icons.tag,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Help text
              MarketSnapStatusMessage(
                message: 'Keywords help customers find relevant answers. Include product names, topics, and related terms.',
                type: StatusType.info,
                showIcon: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.soilTaupe)),
          ),
          MarketSnapPrimaryButton(
            text: existingFAQ == null ? 'Add FAQ' : 'Save Changes',
            onPressed: () {
              // Validate inputs
              if (questionController.text.trim().isEmpty ||
                  answerController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: MarketSnapStatusMessage(
                      message: 'Question and answer are required',
                      type: StatusType.error,
                      showIcon: true,
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                );
                return;
              }
              
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _saveFAQ(
        existingFAQ: existingFAQ,
        question: questionController.text.trim(),
        answer: answerController.text.trim(),
        category: categoryController.text.trim().toLowerCase(),
        keywords: keywordsController.text
            .split(',')
            .map((k) => k.trim().toLowerCase())
            .where((k) => k.isNotEmpty)
            .toList(),
      );
    }
    
    questionController.dispose();
    answerController.dispose();
    categoryController.dispose();
    keywordsController.dispose();
  }

  /// Save FAQ to Firestore
  Future<void> _saveFAQ({
    FAQVector? existingFAQ,
    required String question,
    required String answer,
    required String category,
    required List<String> keywords,
  }) async {
    if (_currentVendorId == null) return;
    
    try {
      developer.log('[VendorKnowledgeBaseScreen] Saving FAQ: $question');
      
      final now = DateTime.now();
      final chunkText = '$question $answer'; // Combined text for embedding
      
      final faqData = {
        'vendorId': _currentVendorId!,
        'question': question,
        'answer': answer,
        'chunkText': chunkText,
        'keywords': keywords,
        'category': category,
        'updatedAt': Timestamp.fromDate(now),
      };
      
      if (existingFAQ == null) {
        // Create new FAQ
        faqData['createdAt'] = Timestamp.fromDate(now);
        await _firestore.collection('faqVectors').add(faqData);
        
        developer.log('[VendorKnowledgeBaseScreen] ✅ Created new FAQ');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: MarketSnapStatusMessage(
                message: 'FAQ added successfully! Vectorization in progress...',
                type: StatusType.success,
                showIcon: true,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          );
        }
      } else {
        // Update existing FAQ
        await _firestore.collection('faqVectors').doc(existingFAQ.id).update(faqData);
        
        developer.log('[VendorKnowledgeBaseScreen] ✅ Updated FAQ: ${existingFAQ.id}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MarketSnapStatusMessage(
              message: 'FAQ updated successfully! Re-vectorization in progress...',
              type: StatusType.success,
              showIcon: true,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }
      
      // Reload FAQs to show changes
      await _loadFAQs();
    } catch (e) {
      developer.log('[VendorKnowledgeBaseScreen] ❌ Error saving FAQ: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MarketSnapStatusMessage(
            message: 'Failed to save FAQ: $e',
            type: StatusType.error,
            showIcon: true,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );
    }
  }

  /// Delete FAQ with confirmation
  Future<void> _deleteFAQ(FAQVector faq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.eggshell,
        title: Text(
          'Delete FAQ',
          style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this FAQ?',
              style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.edgeInsetsCard,
              decoration: BoxDecoration(
                color: AppColors.cornsilk,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.seedBrown),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q: ${faq.question}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.soilCharcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A: ${faq.answer}',
                    style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MarketSnapStatusMessage(
              message: 'This action cannot be undone',
              type: StatusType.warning,
              showIcon: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.body.copyWith(color: AppColors.soilTaupe)),
          ),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.preferredTouchTarget,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appleRed,
                foregroundColor: Colors.white,
                elevation: AppSpacing.elevationSm,
                shadowColor: AppColors.appleRed.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.preferredTouchTarget / 2),
                ),
              ),
              child: Text('Delete', style: AppTypography.buttonLarge),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        developer.log('[VendorKnowledgeBaseScreen] Deleting FAQ: ${faq.id}');
        
        await _firestore.collection('faqVectors').doc(faq.id).delete();
        
        developer.log('[VendorKnowledgeBaseScreen] ✅ Deleted FAQ: ${faq.id}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MarketSnapStatusMessage(
              message: 'FAQ deleted successfully',
              type: StatusType.success,
              showIcon: true,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
        
        // Reload FAQs to show changes
        await _loadFAQs();
      } catch (e) {
        developer.log('[VendorKnowledgeBaseScreen] ❌ Error deleting FAQ: $e');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MarketSnapStatusMessage(
              message: 'Failed to delete FAQ: $e',
              type: StatusType.error,
              showIcon: true,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }
    }
  }

  /// Get analytics summary for an FAQ
  Map<String, int> _getAnalyticsSummary(String faqId) {
    final feedback = _analytics[faqId] ?? [];
    final summary = <String, int>{
      'views': 0,
      'upvotes': 0,
      'downvotes': 0,
      'expansions': 0,
    };
    
    for (final item in feedback) {
      switch (item.action) {
        case RAGFeedbackAction.view:
          summary['views'] = (summary['views'] ?? 0) + 1;
          break;
        case RAGFeedbackAction.upvote:
          summary['upvotes'] = (summary['upvotes'] ?? 0) + 1;
          break;
        case RAGFeedbackAction.downvote:
          summary['downvotes'] = (summary['downvotes'] ?? 0) + 1;
          break;
        case RAGFeedbackAction.expand:
          summary['expansions'] = (summary['expansions'] ?? 0) + 1;
          break;
        default:
          break;
      }
    }
    
    return summary;
  }

  /// Batch vectorize all pending FAQs
  Future<void> _batchVectorizeAllFAQs() async {
    if (_currentVendorId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      developer.log('[VendorKnowledgeBaseScreen] Starting batch vectorization for vendor: $_currentVendorId');
      
      // Call the Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('batchVectorizeFAQs');
      final result = await callable.call({
        'vendorId': _currentVendorId,
        'limit': 50,
      });
      
      final data = result.data;
      developer.log('[VendorKnowledgeBaseScreen] Batch vectorization result: $data');
      
      if (data['success'] == true) {
        final processed = data['processed'] ?? 0;
        
        // Refresh FAQ data to show updated vectorization status
        await _loadFAQs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully vectorized $processed FAQs'),
              backgroundColor: AppColors.leafGreen,
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Vectorization failed');
      }
    } catch (e) {
      developer.log('[VendorKnowledgeBaseScreen] Error during batch vectorization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error vectorizing FAQs: $e'),
            backgroundColor: AppColors.appleRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Build FAQ management tab
  Widget _buildFAQManagementTab() {
    developer.log('[VendorKnowledgeBaseScreen] Building FAQ Management Tab - FAQs count: ${_faqs.length}, Loading: $_isLoading');
    
    return Padding(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your FAQ Library',
                      style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
                    ),
                    Text(
                      '${_faqs.length} questions and answers',
                      style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 90, // Ensure it never exceeds this width
                  minHeight: 36, // Minimum touch target
                ),
                child: ElevatedButton(
                  onPressed: () => _showFAQDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.marketBlue,
                    foregroundColor: Colors.white,
                    elevation: AppSpacing.elevationSm,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    minimumSize: const Size(0, 36), // Ensure minimum touch target
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        'Add',
                        style: AppTypography.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Help information
          if (_faqs.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: AppSpacing.edgeInsetsCard,
              decoration: BoxDecoration(
                color: AppColors.marketBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.marketBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.marketBlue,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Start Building Your Knowledge Base',
                    style: AppTypography.h2.copyWith(color: AppColors.marketBlue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add frequently asked questions to help customers learn about your products. These will appear automatically when relevant to their posts.',
                    style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MarketSnapStatusMessage(
                    message: 'Example questions: "Are your tomatoes organic?", "What days are you at the market?", "Do you accept credit cards?"',
                    type: StatusType.info,
                    showIcon: true,
                  ),
                ],
              ),
            ),
          ] else ...[
            // FAQ list
            Expanded(
              child: ListView.builder(
                itemCount: _faqs.length,
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  final analytics = _getAnalyticsSummary(faq.id);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    color: AppColors.eggshell,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(color: AppColors.seedBrown),
                    ),
                    child: Padding(
                      padding: AppSpacing.edgeInsetsCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FAQ content
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Q: ${faq.question}',
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.soilCharcoal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'A: ${faq.answer}',
                                      style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    
                                    // Category and keywords
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.marketBlue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                          ),
                                          child: Text(
                                            faq.category,
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.marketBlue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        ...faq.keywords.take(3).map((keyword) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.leafGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                          ),
                                          child: Text(
                                            keyword,
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.leafGreen,
                                            ),
                                          ),
                                        )).toList(),
                                        if (faq.keywords.length > 3)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.soilTaupe.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                            ),
                                            child: Text(
                                              '+${faq.keywords.length - 3}',
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.soilTaupe,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Action buttons
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () => _showFAQDialog(existingFAQ: faq),
                                    icon: const Icon(Icons.edit),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.marketBlue.withValues(alpha: 0.1),
                                      foregroundColor: AppColors.marketBlue,
                                    ),
                                    tooltip: 'Edit FAQ',
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  IconButton(
                                    onPressed: () => _deleteFAQ(faq),
                                    icon: const Icon(Icons.delete),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.appleRed.withValues(alpha: 0.1),
                                      foregroundColor: AppColors.appleRed,
                                    ),
                                    tooltip: 'Delete FAQ',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Analytics summary
                          if (analytics['views']! > 0) ...[
                            const Divider(color: AppColors.seedBrown),
                            Row(
                              children: [
                                _buildAnalyticsChip(
                                  icon: Icons.visibility,
                                  label: 'Views',
                                  value: analytics['views']!,
                                  color: AppColors.marketBlue,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _buildAnalyticsChip(
                                  icon: Icons.thumb_up,
                                  label: 'Upvotes',
                                  value: analytics['upvotes']!,
                                  color: AppColors.leafGreen,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _buildAnalyticsChip(
                                  icon: Icons.thumb_down,
                                  label: 'Downvotes',
                                  value: analytics['downvotes']!,
                                  color: AppColors.appleRed,
                                ),
                              ],
                            ),
                          ],
                          
                          // Embedding status
                          Row(
                            children: [
                              Icon(
                                faq.embedding != null ? Icons.check_circle : Icons.schedule,
                                size: 14,
                                color: faq.embedding != null ? AppColors.leafGreen : AppColors.sunsetAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                faq.embedding != null ? 'Vectorized' : 'Pending vectorization',
                                style: AppTypography.caption.copyWith(
                                  color: faq.embedding != null ? AppColors.leafGreen : AppColors.sunsetAmber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build analytics tab
  Widget _buildAnalyticsTab() {
    // Calculate overall analytics
    final totalViews = _analytics.values
        .expand((feedback) => feedback)
        .where((f) => f.action == RAGFeedbackAction.view)
        .length;
    
    final totalUpvotes = _analytics.values
        .expand((feedback) => feedback)
        .where((f) => f.action == RAGFeedbackAction.upvote)
        .length;
    
    final totalDownvotes = _analytics.values
        .expand((feedback) => feedback)
        .where((f) => f.action == RAGFeedbackAction.downvote)
        .length;
    
    final satisfactionRate = totalUpvotes + totalDownvotes > 0
        ? (totalUpvotes / (totalUpvotes + totalDownvotes)) * 100
        : 0.0;
    
    // Top performing FAQs
    final faqPerformance = <String, Map<String, dynamic>>{};
    for (final faq in _faqs) {
      final analytics = _getAnalyticsSummary(faq.id);
      final totalInteractions = analytics['views']! + analytics['upvotes']! + analytics['downvotes']!;
      
      if (totalInteractions > 0) {
        faqPerformance[faq.id] = {
          'faq': faq,
          'interactions': totalInteractions,
          'satisfaction': analytics['upvotes']! + analytics['downvotes']! > 0
              ? (analytics['upvotes']! / (analytics['upvotes']! + analytics['downvotes']!)) * 100
              : 0.0,
        };
      }
    }
    
    // Sort by interactions
    final topFAQs = faqPerformance.entries.toList()
      ..sort((a, b) => b.value['interactions'].compareTo(a.value['interactions']));
    
    return Padding(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Knowledge Base Analytics',
            style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'See how customers interact with your FAQs',
            style: AppTypography.body.copyWith(color: AppColors.soilTaupe),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Overall statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Views',
                  value: totalViews.toString(),
                  icon: Icons.visibility,
                  color: AppColors.marketBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  title: 'Satisfaction Rate',
                  value: '${satisfactionRate.toStringAsFixed(1)}%',
                  icon: Icons.sentiment_satisfied,
                  color: satisfactionRate >= 70 ? AppColors.leafGreen : AppColors.sunsetAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Upvotes',
                  value: totalUpvotes.toString(),
                  icon: Icons.thumb_up,
                  color: AppColors.leafGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  title: 'Downvotes',
                  value: totalDownvotes.toString(),
                  icon: Icons.thumb_down,
                  color: AppColors.appleRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Vectorization Status & Actions
          Container(
            width: double.infinity,
            padding: AppSpacing.edgeInsetsCard,
            decoration: BoxDecoration(
              color: AppColors.sunsetAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.sunsetAmber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      color: AppColors.sunsetAmber,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'AI Vectorization Status',
                        style: AppTypography.body.copyWith(
                          color: AppColors.sunsetAmber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_faqs.where((faq) => faq.embedding == null).length} of ${_faqs.length} FAQs need vectorization for optimal search results.',
                  style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
                ),
                if (_faqs.any((faq) => faq.embedding == null)) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _batchVectorizeAllFAQs,
                      icon: _isLoading 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(_isLoading ? 'Vectorizing...' : 'Vectorize Pending FAQs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sunsetAmber,
                        foregroundColor: Colors.white,
                        elevation: AppSpacing.elevationSm,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Top performing FAQs
          if (topFAQs.isNotEmpty) ...[
            Text(
              'Top Performing FAQs',
              style: AppTypography.h2.copyWith(color: AppColors.soilCharcoal),
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Use SizedBox with fixed height instead of Expanded to prevent overflow
            SizedBox(
              height: 300, // Fixed height to prevent overflow issues
              child: ListView.builder(
                itemCount: topFAQs.length,
                itemBuilder: (context, index) {
                  final entry = topFAQs[index];
                  final faq = entry.value['faq'] as FAQVector;
                  final interactions = entry.value['interactions'] as int;
                  final satisfaction = entry.value['satisfaction'] as double;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    color: AppColors.eggshell,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      side: BorderSide(color: AppColors.seedBrown),
                    ),
                    child: Padding(
                      padding: AppSpacing.edgeInsetsCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faq.question,
                            style: AppTypography.body.copyWith(
                              color: AppColors.soilCharcoal,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          
                          Row(
                            children: [
                              _buildAnalyticsChip(
                                icon: Icons.trending_up,
                                label: 'Interactions',
                                value: interactions,
                                color: AppColors.marketBlue,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildAnalyticsChip(
                                icon: Icons.sentiment_satisfied,
                                label: 'Satisfaction',
                                value: satisfaction.toInt(),
                                suffix: '%',
                                color: satisfaction >= 70 ? AppColors.leafGreen : AppColors.sunsetAmber,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: AppSpacing.edgeInsetsCard,
              decoration: BoxDecoration(
                color: AppColors.soilTaupe.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.soilTaupe.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics,
                    color: AppColors.soilTaupe,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Analytics Yet',
                    style: AppTypography.h2.copyWith(color: AppColors.soilTaupe),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Analytics will appear here once customers start interacting with your FAQs.',
                    style: AppTypography.body.copyWith(color: AppColors.soilCharcoal),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build analytics chip widget
  Widget _buildAnalyticsChip({
    required IconData icon,
    required String label,
    required int value,
    String suffix = '',
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value$suffix',
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build statistics card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: AppSpacing.edgeInsetsCard,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: AppTypography.h1.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.body.copyWith(
              color: AppColors.soilCharcoal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cornsilk,
      appBar: AppBar(
        backgroundColor: AppColors.cornsilk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.soilCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Knowledge Base',
          style: AppTypography.h1.copyWith(color: AppColors.soilCharcoal),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.marketBlue,
          unselectedLabelColor: AppColors.soilTaupe,
          indicatorColor: AppColors.marketBlue,
          tabs: const [
            Tab(text: 'Manage FAQs'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.marketBlue),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFAQManagementTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }
} 