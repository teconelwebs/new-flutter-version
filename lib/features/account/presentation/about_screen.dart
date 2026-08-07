import 'package:flutter/material.dart';
import '../../../core/utils/safe_insets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About Us',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: 24 + systemBottomInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Our Story
            const Text(
              'Our Story',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Online Shopping Redefined at Welfog Internet Private Limited',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welfog brings a fashion revolution to your doorstep with seamless online shopping. Discover on-trend styles and curated collections of clothing, footwear, accessories, and more for men, women, and kids from the most coveted designer brands.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Revamp your wardrobe from the comfort of your home with statement pieces that reflect your unique style. Beyond fashion, explore our finest beauty and home decor products—all carefully chosen to inspire you and help you create a confident, personalized look.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 36),
            
            // Section 2: What We Do
            const Text(
              'What We Do',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            
            _buildFeatureItem(
              'Provide a wide range of quality products across categories',
            ),
            _buildFeatureItem(
              'Offer engaging video content and tutorials for smarter shopping',
            ),
            _buildFeatureItem(
              'Ensure safe, simple, and fast checkout with real-time tracking',
            ),
            _buildFeatureItem(
              'Deliver personalized recommendations and exclusive offers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFFFB5404),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
