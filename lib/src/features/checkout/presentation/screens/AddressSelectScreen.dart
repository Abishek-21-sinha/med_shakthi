import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../models/AddressModel.dart';
import '../AddressStore.dart';
import 'PaymentMethodScreen.dart';



class AddressSelectScreen extends StatefulWidget {
  const AddressSelectScreen({super.key});

  @override
  State<AddressSelectScreen> createState() => _AddressSelectScreenState();
}

class _AddressSelectScreenState extends State<AddressSelectScreen> {
  GoogleMapController? mapController;
  LatLng selectedLatLng = const LatLng(28.6139, 77.2090);
  String addressText = "Tap on map to select address";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getAddress(LatLng pos) async {
    final placemarks =
    await placemarkFromCoordinates(pos.latitude, pos.longitude);
    final p = placemarks.first;

    setState(() {
      addressText =
      "${p.street}, ${p.locality}, ${p.administrativeArea}, ${p.postalCode}";
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        setState(() {
          selectedLatLng = latLng;
        });
        await _getAddress(latLng);
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address not found")),
      );
    }
  }

  void _showAddAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search for address",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: _searchAddress,
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: selectedLatLng,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => mapController = controller,
                    onTap: (pos) {
                      selectedLatLng = pos;
                      _getAddress(pos);
                    },
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                      ),
                    }.toSet(),
                    markers: {
                      Marker(
                        markerId: const MarkerId("selected"),
                        position: selectedLatLng,
                      ),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        addressText,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () {
                          final address = AddressModel(
                            id: DateTime.now().toString(),
                            title: "Home",
                            fullAddress: addressText,
                            lat: selectedLatLng.latitude,
                            lng: selectedLatLng.longitude,
                          );

                          AddressStore.addAddress(address);
                          Navigator.pop(context); // Close bottom sheet
                          setState(() {}); // Refresh list
                        },
                        child: const Text(
                          "Save Address",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Address"), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: AddressStore.addresses.length,
        itemBuilder: (_, i) {
          final address = AddressStore.addresses[i];

          return GestureDetector(
            onTap: () {
              AddressStore.selectAddress(address.id);
              setState(() {});
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaymentMethodScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                  address.isSelected ? Colors.teal : Colors.grey.shade300,
                  width: 1.5,
                ),
                boxShadow: address.isSelected
                    ? [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: address.isSelected ? Colors.teal : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                            address.isSelected ? Colors.teal : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address.fullAddress,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (address.isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Selected",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _showAddAddressBottomSheet,
          child: const Text(
            "Add New Address",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// class AddressSelectScreen extends StatefulWidget {
//   const AddressSelectScreen({super.key});

//   @override
//   State<AddressSelectScreen> createState() => _AddressSelectScreenState();
// }

// class _AddressSelectScreenState extends State<AddressSelectScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Select Address")),
//       body: ListView.builder(
//         padding: const EdgeInsets.all(16),
//         itemCount: AddressStore.addresses.length,
//         itemBuilder: (_, i) {
//           final address = AddressStore.addresses[i];
//           return GestureDetector(
//             onTap: () {
//               AddressStore.selectAddress(address.id);
//               Navigator.pop(context);
//             },
//             child: Container(
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(
//                   color: address.isSelected
//                       ? Colors.teal
//                       : Colors.grey.shade300,
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(address.title,
//                       style: const TextStyle(fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 6),
//                   Text(address.fullAddress),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ElevatedButton(
//           onPressed: () async {
//             final newAddress = await Navigator.push(
//               context,
//               MaterialPageRoute(builder: (_) => const AddAddressScreen()),
//             );

//             if (newAddress != null) {
//               AddressStore.addAddress(newAddress);
//               setState(() {});
//             }
//           },
//           child: const Text("Add New Address"),
//         ),
//       ),
//     );
//   }
// }
