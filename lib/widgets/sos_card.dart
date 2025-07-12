import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Sos_Card extends StatelessWidget {
  final Map<String, dynamic> request;
  const Sos_Card({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with profile and name
            Row(
              children: [
               CircleAvatar(
                backgroundImage: NetworkImage(request['photo_url']),
               ),
                // CircleAvatar(
                //   backgroundImage: request['profile_url'] != null &&
                //           request['profile_url'].toString().startsWith('http')
                //       ? CachedNetworkImageProvider(request['profile_url'])
                //       : const AssetImage('zob_assets/profile.png') as ImageProvider,
                //   radius: 25,
                // ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      request['car_model'] ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                if (request['is_urgent'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Issue image and description
            Row(
              children: [
                Image.network(
                  request['profile_url'],
                  height: 80,
                  fit:BoxFit.cover ,
                  
                ),
                
                // request['photo_url'] != null &&
                //         request['photo_url'].toString().startsWith('http')
                //     ? CachedNetworkImage(
                //         imageUrl: request['photo_url'],
                //         width: 80,
                //         height: 80,
                //         fit: BoxFit.cover,
                //         placeholder: (context, url) => const SizedBox(
                //           width: 80,
                //           height: 80,
                //           child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                //         ),
                //         errorWidget: (context, url, error) => Image.asset(
                //           'zob_assets/dplaceholder.png',
                //           width: 80,
                //           height: 80,
                //           fit: BoxFit.cover,
                //         ),
                //       )
                //     : Image.asset(
                //         'zob_assets/dplaceholder.png',
                //         width: 80,
                //         height: 80,
                //         fit: BoxFit.cover,
                //       ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Issue Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(request['issue_description'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location row
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                Text(request['location'] ?? ''),
                const Spacer(),
                Text(
                  '${request['distance_km'] ?? 0} km away',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Phone container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(request['phone'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Add ignore action
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Ignore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Add accept action
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
}
