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

class _HistoryPageState extends State<HistoryPage> 
    with TickerProviderStateMixin {
  List<ServiceHistory> _serviceHistory = [];
  List<Map<String, dynamic>> _completedRequests = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    
    _loadServiceHistory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
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
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Colors.white,
              AppColors.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative elements
              Positioned(
                top: -100,
                right: -100,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.primary.withOpacity(0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Main content
              CustomScrollView(
                slivers: [
                  // Enhanced App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/userHome', (route) => false);
                        },
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.1),
                              child: IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: () {
                                  _loadServiceHistory();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decorative circles
                            Positioned(
                              top: 20,
                              right: 30,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 40,
                              right: 80,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                            ),
                            // Title with history count
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Service",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: FontSizes.body,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "History",
                                            style: AppTextStyles.heading.copyWith(
                                              color: Colors.white,
                                              fontSize: FontSizes.heading,
                                              fontFamily: AppFonts.primaryFont,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_isLoading && allServiceInteractions.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          '${allServiceInteractions.length} ${allServiceInteractions.length == 1 ? 'Service' : 'Services'}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: FontSizes.caption,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Content
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _isLoading
                          ? _buildEnhancedShimmerLoading()
                          : _errorMessage != null
                              ? _buildEnhancedErrorState()
                              : Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
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
                                    allServiceInteractions.isEmpty
                                        ? _buildEnhancedEmptyState()
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: Column(
                                              children: allServiceInteractions.asMap().entries.map((entry) {
                                                final index = entry.key;
                                                final item = entry.value;
                                                return TweenAnimationBuilder<double>(
                                                  duration: Duration(milliseconds: 600 + (index * 100)),
                                                  tween: Tween(begin: 0.0, end: 1.0),
                                                  builder: (context, value, child) {
                                                    return Transform.translate(
                                                      offset: Offset((1 - value) * 300, 0),
                                                      child: Opacity(
                                                        opacity: value,
                                                        child: item is ServiceHistory
                                                            ? (item.rating > 0
                                                                ? _buildEnhancedReviewedServiceCard(item)
                                                                : _buildEnhancedPendingReviewCard(item))
                                                            : _buildEnhancedUnratedRequestCard(item),
                                                      ),
                                                    );
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildEnhancedShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header shimmer
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                gradient: LinearGradient(
                                  begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                                  end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                                  colors: [
                                    Colors.grey.shade300,
                                    Colors.grey.shade100,
                                    Colors.grey.shade300,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 80,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                                end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                                colors: [
                                  Colors.grey.shade300,
                                  Colors.grey.shade100,
                                  Colors.grey.shade300,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Date shimmer
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                            end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade100,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Content shimmer
                      Container(
                        height: 14,
                        width: double.infinity * 0.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerAnimation.value * 2, 0.0),
                            end: Alignment(1.0 + _shimmerAnimation.value * 2, 0.0),
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade100,
                              Colors.grey.shade300,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEnhancedErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withOpacity(0.1),
                          Colors.red.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: FontSizes.subHeading,
                color: Colors.red,
                fontFamily: AppFonts.primaryFont,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _loadServiceHistory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppFonts.primaryFont,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced animated icon with gradient background
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primary.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.history,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Enhanced title
            Text(
              'No service history found',
              style: TextStyle(
                fontSize: FontSizes.heading,
                fontFamily: AppFonts.primaryFont,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            
            // Enhanced subtitle
            Text(
              'Your completed services will appear here for rating',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: FontSizes.body,
                fontFamily: AppFonts.primaryFont,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            
            // Enhanced action button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pushNamed(context, '/find-mechanics');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Find Mechanics',
                          style: TextStyle(
                            fontFamily: AppFonts.primaryFont,
                            fontSize: FontSizes.body,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPendingReviewCard(ServiceHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange,
                              Colors.orange.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(history.serviceDate),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Service entry exists but needs your review. Please rate this mechanic.',
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.body,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _updateExistingReview(history),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Review',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: FontSizes.body,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primaryFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedReviewedServiceCard(ServiceHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green,
                              Colors.green.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'REVIEWED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(history.serviceDate),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.1),
                    Colors.amber.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Icon(
                      index < history.rating
                          ? Icons.star
                          : Icons.star_border,
                      size: 20,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      history.rating.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (history.userReview.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Review:',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      history.userReview,
                      style: AppTextStyles.body.copyWith(
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
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

  Widget _buildEnhancedUnratedRequestCard(Map<String, dynamic> request) {
    final mechanicName = request['mechanics']?['users']?['full_name'] ?? 'Unknown Mechanic';
    final serviceDate = DateTime.parse(request['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange,
                              Colors.orange.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM dd, yyyy').format(serviceDate),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Service completed successfully. How was your experience?',
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.body,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _rateService(request),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rate,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rate Service',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: FontSizes.body,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primaryFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
