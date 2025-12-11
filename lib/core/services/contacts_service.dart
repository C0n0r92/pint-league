import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactsService {
  final SupabaseClient _supabase;

  ContactsService(this._supabase);

  /// Normalize phone number to E.164 format
  /// Detects country from phone prefix or uses user's profile country
  String _normalizePhone(String phone, {String? defaultCountry}) {
    // Auto-detect country if not provided
    final country = defaultCountry ?? _detectCountryFromPhone(phone) ?? 'GB';
    return _normalizePhoneWithCountry(phone, country);
  }

  String? _detectCountryFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+353') || digits.startsWith('353')) return 'IE';
    if (digits.startsWith('+44') || digits.startsWith('44')) return 'GB';
    if (digits.startsWith('08')) return 'IE'; // Irish mobile
    if (digits.startsWith('07')) return 'GB'; // UK mobile
    return null;
  }

  String _normalizePhoneWithCountry(String phone, String country) {
    // Remove all non-digits except leading +
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Handle local numbers starting with 0
    if (digits.startsWith('0')) {
      if (country == 'IE') {
        digits = '353${digits.substring(1)}';
      } else {
        digits = '44${digits.substring(1)}';
      }
    }

    // If no country code, add based on detected country
    if (!digits.startsWith('44') && !digits.startsWith('353') && !digits.startsWith('1')) {
      if (country == 'IE') {
        digits = '353$digits';
      } else {
        digits = '44$digits';
      }
    }

    return '+$digits';
  }

  /// Hash phone number using SHA256
  String _hashPhone(String normalizedPhone) {
    final bytes = utf8.encode(normalizedPhone);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save user's phone number for discovery by friends
  Future<void> saveUserPhone(String phoneNumber) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final normalized = _normalizePhone(phoneNumber);
    final hash = _hashPhone(normalized);

    await _supabase.from('phone_hashes').upsert({
      'user_id': userId,
      'phone_hash': hash,
    }, onConflict: 'phone_hash');
  }

  /// Find friends from device contacts
  Future<List<Map<String, dynamic>>> findFriendsFromContacts() async {
    // Request contacts permission
    final status = await Permission.contacts.request();
    if (!status.isGranted) return [];

    // Get all contacts with phone numbers
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: false,
    );

    // Extract and hash all phone numbers
    final hashes = <String>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = _normalizePhone(phone.number);
        final hash = _hashPhone(normalized);
        hashes.add(hash);
      }
    }

    if (hashes.isEmpty) return [];

    // Query Supabase for matching users
    final result = await _supabase.rpc('find_friends_by_phone_hashes', params: {
      'hashes': hashes,
    });

    return List<Map<String, dynamic>>.from(result ?? []);
  }

  /// Search for users by username
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.length < 2) return [];

    final response = await _supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .ilike('username', '%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Check if user has granted contacts permission
  Future<bool> hasContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Request contacts permission
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }
}

