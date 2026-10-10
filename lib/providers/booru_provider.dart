import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booru_site.dart';

class BooruProvider extends ChangeNotifier {
  static const String _keySites = 'flexbooru_sites';
  static const String _keyActiveId = 'flexbooru_active_site_id';

  List<BooruSite> _sites = [];
  BooruSite? _activeSite;
  bool _isLoading = true;

  List<BooruSite> get sites => _sites;
  BooruSite? get activeSite => _activeSite;
  bool get isLoading => _isLoading;

  BooruProvider() {
    loadSites();
  }

  Future<void> loadSites() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final sitesJson = prefs.getString(_keySites);
    final activeId = prefs.getString(_keyActiveId);

    if (sitesJson != null && sitesJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(sitesJson);
        _sites = list
            .map((e) => BooruSite.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _sites = BooruSite.defaultPresets;
      }
    } else {
      _sites = BooruSite.defaultPresets;
    }

    final hadRetiredSites = _sites.any((site) => site.isRetiredPreset);
    _sites.removeWhere((site) => site.isRetiredPreset);

    if (_sites.isEmpty) {
      _sites = BooruSite.defaultPresets;
    }

    if (activeId != null) {
      _activeSite = _sites.firstWhere(
        (s) => s.id == activeId,
        orElse: () => _sites.first,
      );
    } else {
      _activeSite = _sites.first;
    }

    if (hadRetiredSites) {
      await _saveSites();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_sites.map((e) => e.toJson()).toList());
    await prefs.setString(_keySites, jsonString);
    if (_activeSite != null) {
      await prefs.setString(_keyActiveId, _activeSite!.id);
    }
  }

  Future<void> setActiveSite(BooruSite site) async {
    _activeSite = site;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveId, site.id);
    notifyListeners();
  }

  Future<void> addSite(BooruSite site) async {
    _sites.add(site);
    _activeSite ??= site;
    await _saveSites();
    notifyListeners();
  }

  Future<void> updateSite(BooruSite site) async {
    final index = _sites.indexWhere((s) => s.id == site.id);
    if (index != -1) {
      _sites[index] = site;
      if (_activeSite?.id == site.id) {
        _activeSite = site;
      }
      await _saveSites();
      notifyListeners();
    }
  }

  Future<void> deleteSite(String id) async {
    _sites.removeWhere((s) => s.id == id);
    if (_activeSite?.id == id) {
      _activeSite = _sites.isNotEmpty ? _sites.first : null;
    }
    await _saveSites();
    notifyListeners();
  }

  Future<void> resetToPresets() async {
    _sites = List.from(BooruSite.defaultPresets);
    _activeSite = _sites.first;
    await _saveSites();
    notifyListeners();
  }

  Future<bool> importFromBooruUri(String uriString) async {
    final site = BooruSite.fromBooruUri(uriString);
    if (site != null) {
      await addSite(site);
      await setActiveSite(site);
      return true;
    }
    return false;
  }

  String exportToJson() {
    return jsonEncode(_sites.map((e) => e.toJson()).toList());
  }

  Future<bool> importFromJson(String jsonString) async {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      final imported = list
          .map((e) => BooruSite.fromJson(e as Map<String, dynamic>))
          .toList();
      if (imported.isNotEmpty) {
        _sites.addAll(imported);
        await _saveSites();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
