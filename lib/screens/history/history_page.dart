import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/service_history.dart';
import '../rating/rate_mechanic_screen.dart';
import '../../widgets/bottom_navbar.dart';
import 'package:mechfind/utils.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ServiceHistory> _serviceHistory = [];
  List<Map<String, dynamic>> _completedRequests = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServiceHistory();
  }

  Future<void> _loadServiceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Fetch completed requests with mechanic details
      final completedRequestsResponse = await _supabase
          .from('requests')
          .select('''
            id,
            mechanic_id,
            created_at,
            mechanics(
              users(full_name, image_url)
            )
          ''')
          .eq('user_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      _completedRequests = List<Map<String, dynamic>>.from(completedRequestsResponse);

      // Fetch existing reviews for these mechanics (including null ratings)
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('''
            id,
            mechanic_id,
            rating,
            comment,
            created_at,
            mechanics(
              users(full_name)
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Convert reviews to ServiceHistory objects
      final reviewHistory = reviewsResponse.map<ServiceHistory>((review) {
        return ServiceHistory.fromJson(review);
      }).toList();

      setState(() {
        _serviceHistory = reviewHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load service history: $e';
        _isLoading = false;
      });
      print('Error loading service history: $e');
    }
  }

  // Get mechanics from completed requests that haven't been reviewed yet
  List<Map<String, dynamic>> get unratedMechanics {
    final ratedMechanicIds = _serviceHistory
        .where((h) => h.rating > 0) // Only consider actually rated services
        .map((h) => h.mechanicId)
        .toSet();
    return _completedRequests
        .where((request) => !ratedMechanicIds.contains(request['mechanic_id']))
        .toList();
  }

  // Get reviews that exist but have null rating/comment (pending reviews)
  List<ServiceHistory> get pendingReviews {
    return _serviceHistory.where((h) => h.rating == 0.0).toList();
  }

  // Get actually completed reviews
  List<ServiceHistory> get completedReviews {
    return _serviceHistory.where((h) => h.rating > 0).toList();
  }

  // Combined list of all service interactions
  List<dynamic> get allServiceInteractions {
    final List<dynamic> combined = [];
    
    // Add completed reviews
    combined.addAll(completedReviews);
    
    // Add pending reviews (reviews with null rating)
    combined.addAll(pendingReviews);
    
    // Add unrated completed requests (no review entry at all)
    combined.addAll(unratedMechanics);
    
    // Sort by date (most recent first)
    combined.sort((a, b) {
      DateTime dateA;
      DateTime dateB;
      
      if (a is ServiceHistory) {
        dateA = a.serviceDate;
      } else {
        dateA = DateTime.parse(a['created_at']);
      }
      
      if (b is ServiceHistory) {
        dateB = b.serviceDate;
      } else {
        dateB = DateTime.parse(b['created_at']);
      }
      
      return dateB.compareTo(dateA);
    });
    
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service History',
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
                context, '/userHome', (route) => false);
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadServiceHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Your service history and mechanics you can rate',
                        style: TextStyle(
                          fontFamily: AppFonts.primaryFont,
                          fontSize: FontSizes.body,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: allServiceInteractions.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: allServiceInteractions.length,
                              itemBuilder: (context, index) {
                                final item = allServiceInteractions[index];
                                if (item is ServiceHistory) {
                                  if (item.rating > 0) {
                                    return _buildReviewedServiceCard(item);
                                  } else {
                                    return _buildPendingReviewCard(item);
                                  }
                                } else {
                                  return _buildUnratedRequestCard(item);
                                }
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) return;
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(
                  context, '/userHome', (route) => false);
              break;
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 2:
              Navigator.pushNamed(context, '/messages');
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  Widget _buildPendingReviewCard(ServiceHistory history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.mechanicName,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: FontSizes.subHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NOT REVIEWED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(history.serviceDate),
                  style: AppTextStyles.label,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Service entry exists but needs your review. Please rate this mechanic.',
              style: AppTextStyles.body.copyWith(fontSize: FontSizes.body),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _updateExistingReview(history),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewedServiceCard(ServiceHistory history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.mechanicName,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: FontSizes.subHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REVIEWED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(history.serviceDate),
                  style: AppTextStyles.label,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < history.rating
                        ? Icons.star
                        : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  history.rating.toString(),
                  style: AppTextStyles.label,
                ),
              ],
            ),
            if (history.userReview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Review:',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.userReview,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnratedRequestCard(Map<String, dynamic> request) {
    final mechanicName = request['mechanics']?['users']?['full_name'] ?? 'Unknown Mechanic';
    final serviceDate = DateTime.parse(request['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mechanicName,
                        style: AppTextStyles.heading.copyWith(
                          fontSize: FontSizes.subHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(serviceDate),
                  style: AppTextStyles.label,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Service completed successfully. How was your experience?',
              style: AppTextStyles.body.copyWith(fontSize: FontSizes.body),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _rateService(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Rate Service'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateExistingReview(ServiceHistory history) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateMechanicScreen(
          mechanicId: history.mechanicId,
          mechanicName: history.mechanicName,
          serviceId: history.id,
          onRatingSubmitted: (rating, review) async {
            // Update existing review in database
            try {
              await _supabase.from('reviews').update({
                'rating': rating.round(),
                'comment': review,
              }).eq('id', history.id);
              
              // Refresh the list to show the updated review
              _loadServiceHistory();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Review updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              print('Error updating review: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update review: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _rateService(dynamic item) {
    String mechanicId;
    String mechanicName;
    
    if (item is ServiceHistory) {
      mechanicId = item.mechanicId;
      mechanicName = item.mechanicName;
    } else {
      mechanicId = item['mechanic_id'];
      mechanicName = item['mechanics']?['users']?['full_name'] ?? 'Unknown Mechanic';
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateMechanicScreen(
          mechanicId: mechanicId,
          mechanicName: mechanicName,
          serviceId: '', // Not needed for our use case
          onRatingSubmitted: (rating, review) async {
            // Save review to database
            try {
              final user = _supabase.auth.currentUser;
              if (user != null) {
                await _supabase.from('reviews').insert({
                  'user_id': user.id,
                  'mechanic_id': mechanicId,
                  'rating': rating.round(),
                  'comment': review,
                });
                
                // Refresh the list to show the new review
                _loadServiceHistory();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Review submitted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            } catch (e) {
              print('Error saving review: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save review: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No service history found',
            style: TextStyle(
              fontSize: FontSizes.subHeading,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed services will appear here for rating',
            style: TextStyle(
              fontSize: FontSizes.body,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
