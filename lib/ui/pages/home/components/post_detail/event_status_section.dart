import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/services/location/location_cache_service.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'dart:developer' as developer;

/// A widget that displays and lets users vote on the event status
class EventStatusSection extends StatefulWidget {
  final Post post;
  final VoidCallback? onStatusUpdated;

  const EventStatusSection({
    super.key,
    required this.post,
    this.onStatusUpdated,
  });

  @override
  State<EventStatusSection> createState() => _EventStatusSectionState();
}

class _EventStatusSectionState extends State<EventStatusSection> {
  bool _isUserNearby = false;
  bool _isCheckingProximity = true;
  bool _isVoting = false; // Add loading state for voting

  @override
  void initState() {
    super.initState();
    _calculateDistanceToPost();
  }

  // Calculate distance using LocationCacheService
  Future<void> _calculateDistanceToPost() async {
    if (widget.post.distance > 0) {
      // Distance already calculated, just check proximity
      setState(() {
        _isUserNearby = widget.post.distance <= 100.0;
        _isCheckingProximity = false;
      });
      return;
    }

    setState(() => _isCheckingProximity = true);

    try {
      final locationCache = LocationCacheService();
      await locationCache.initialize();

      var userPosition = locationCache.cachedPosition;

      userPosition ??= await locationCache.forceUpdate();

      if (userPosition != null) {
        final double calculatedDistance = locationCache.calculateDistance(
          widget.post.latitude,
          widget.post.longitude,
        );

        setState(() {
          widget.post.distance = calculatedDistance; // Store in meters
          _isUserNearby = calculatedDistance <= 100.0;
          _isCheckingProximity = false;
        });

        developer.log(
            '🎯 EventStatus: Distance calculated: ${calculatedDistance.toStringAsFixed(1)}m, Within range: $_isUserNearby');
      } else {
        // Fallback - couldn't get location, assume not nearby
        setState(() {
          _isUserNearby = false;
          _isCheckingProximity = false;
        });
        developer.log(
            '❌ EventStatus: Could not get user location for distance calculation');
      }
    } catch (e) {
      setState(() {
        _isUserNearby = false;
        _isCheckingProximity = false;
      });
      developer.log('❌ EventStatus: Error calculating distance: $e');
    }
  }

  // Show distance restriction error message
  void _showDistanceRestrictionError() {
    final distanceText = widget.post.distance > 0
        ? _formatDistance(widget.post.distance)
        : "Unknown distance";

    ResponsiveSnackBar.showError(
      context: context,
      message:
          'You must be within 100m of this location to vote on event status. You are currently $distanceText away.',
      duration: const Duration(seconds: 4),
    );
  }

  // Format distance for display
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  void _voteOnEventStatus(bool eventEnded) async {
    // Prevent multiple simultaneous votes
    if (_isVoting) return;

    // Check distance restriction - only allow voting if user is within 100m
    if (!_isUserNearby) {
      _showDistanceRestrictionError();
      return;
    }

    // Check if user already voted for the same option
    final String currentVote = widget.post.userStatusVote ?? '';
    final String newVote = eventEnded ? 'ended' : 'happening';

    if (currentVote == newVote) {
      // User already voted for this option, just return (no snackbar)
      return;
    }

    // Set loading state
    setState(() => _isVoting = true);

    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    try {
      final Map<String, dynamic> result = await postsProvider.voteOnEventStatus(
        post: widget.post,
        eventEnded: eventEnded,
      );

      if (!mounted) return;

      // Check for valid result with required fields instead of just checking if empty
      if (result.containsKey('status') &&
          (result.containsKey('ended_votes') ||
              result.containsKey('happening_votes'))) {
        // Refresh post data to get updated vote counts and status
        final updatedPost =
            await postsProvider.fetchPostDetails(widget.post.id);
        if (updatedPost != null && mounted) {
          setState(() {
            // Update all the event status fields
            widget.post.isHappening = updatedPost.isHappening;
            widget.post.isEnded = updatedPost.isEnded;
            widget.post.endedVotesCount = updatedPost.endedVotesCount;
            widget.post.happeningVotesCount = updatedPost.happeningVotesCount;
            widget.post.userStatusVote = updatedPost.userStatusVote;
          });

          // Notify parent if needed
          if (widget.onStatusUpdated != null) {
            widget.onStatusUpdated!();
          }
        }
      } else {
        // Show error message for invalid response (only errors, no success snackbars)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postsProvider.errorMessage ??
                  'Failed to vote on event status: Invalid response'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error voting on event status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Get status colors
    final bool isEventActive = widget.post.isEventHappening;
    final Color statusColor =
        isEventActive ? ThemeConstants.green : Colors.grey[600]!;
    final Color bgColor = isEventActive
        ? ThemeConstants.green.withOpacity(0.08)
        : (isDark ? Colors.grey[850]! : Colors.grey[100]!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      width: double.infinity, // Match map width (full width minus margins)
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(
                    isEventActive
                        ? Icons.radio_button_checked
                        : Icons.event_busy,
                    color: statusColor,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEventActive ? 'Event is Active' : 'Event Ended',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Live indicator for active events only
                if (isEventActive) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Only show voting section if event is still active
            if (isEventActive) ...[
              const SizedBox(height: 8),

              // Vote counts - only for active events
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.grey[800]! : Colors.white)
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isDark ? Colors.grey[700] : Colors.grey[300])!,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildVoteCount(
                        icon: Icons.trending_up,
                        label: 'Active',
                        count: widget.post.happeningVotesCount ?? 0,
                        color: ThemeConstants.green,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: (isDark ? Colors.grey[600] : Colors.grey[300]),
                    ),
                    Expanded(
                      child: _buildVoteCount(
                        icon: Icons.trending_down,
                        label: 'Ended',
                        count: widget.post.endedVotesCount ?? 0,
                        color: Colors.grey[600]!,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Voting buttons - only for active events
              _isCheckingProximity
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _buildVotingButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoteCount({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVotingButtons() {
    // Check user's current vote
    final String userVote = widget.post.userStatusVote ?? '';
    final bool hasVotedHappening = userVote == 'happening';
    final bool hasVotedEnded = userVote == 'ended';

    return Column(
      children: [
        Row(
          children: [
            // "Still Active" button
            Expanded(
              child: _buildStatusButton(
                onPressed: (hasVotedHappening || !_isUserNearby)
                    ? null
                    : () => _voteOnEventStatus(false),
                icon: hasVotedHappening
                    ? Icons.check_circle
                    : Icons.radio_button_checked,
                label: hasVotedHappening ? 'Voted: Active' : 'Still Active',
                isSelected: hasVotedHappening,
                color: ThemeConstants.green,
                isDisabled: hasVotedHappening || !_isUserNearby,
                isLoading: _isVoting &&
                    !hasVotedHappening, // Show loading for this button when voting for "happening"
              ),
            ),

            const SizedBox(width: 6),

            // "Event Ended" button
            Expanded(
              child: _buildStatusButton(
                onPressed: (hasVotedEnded || !_isUserNearby)
                    ? null
                    : () => _voteOnEventStatus(true),
                icon: hasVotedEnded ? Icons.check_circle : Icons.event_busy,
                label: hasVotedEnded ? 'Voted: Ended' : 'Mark Ended',
                isSelected: hasVotedEnded,
                color: Colors.orange[700]!,
                isDisabled: hasVotedEnded || !_isUserNearby,
                isLoading: _isVoting &&
                    !hasVotedEnded, // Show loading for this button when voting for "ended"
              ),
            ),
          ],
        ),

        // Show user's vote status
        if (hasVotedHappening || hasVotedEnded) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (hasVotedHappening ? ThemeConstants.green : Colors.orange)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hasVotedHappening ? '✓ You voted: Active' : '✓ You voted: Ended',
              style: TextStyle(
                fontSize: 10,
                color: hasVotedHappening
                    ? ThemeConstants.green
                    : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required bool isDisabled,
    bool isLoading = false, // Add isLoading parameter
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Opacity(
        opacity: (!_isUserNearby && !isSelected) ? 0.5 : 1.0,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[800] : Colors.white),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDisabled
                        ? color.withOpacity(0.3)
                        : color.withOpacity(0.5)),
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show loading indicator or icon
                if (isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSelected ? Colors.white : color,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected
                        ? Colors.white
                        : (isDisabled ? color.withOpacity(0.5) : color),
                  ),
                const SizedBox(width: 4),
                Text(
                  isLoading ? 'Voting...' : label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white
                        : (isDisabled ? color.withOpacity(0.5) : color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
