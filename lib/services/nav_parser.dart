//navigations
// ignore_for_file: constant_identifier_names, empty_catches

import 'package:audio_service/audio_service.dart';

import '/models/media_Item_builder.dart';
import '/services/utils.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';

const single_column = ['contents', 'singleColumnBrowseResultsRenderer'];
const tab_content = ['tabs', 0, 'tabRenderer', 'content'];
const List<dynamic> single_column_tab = [
  'contents',
  'singleColumnBrowseResultsRenderer',
  'tabs',
  0,
  'tabRenderer',
  'content'
];
const section_list = ['sectionListRenderer', 'contents'];
const description_shelf = ['musicDescriptionShelfRenderer'];
const run_text = ['runs', 0, 'text'];
const description = ['description', 'runs', 0, 'text'];
const carousel_title = [
  'header',
  'musicCarouselShelfBasicHeaderRenderer',
  'title',
  'runs',
  0
];
const mtrir = 'musicTwoRowItemRenderer';
const mrlir = 'musicResponsiveListItemRenderer';
const n_title = ['title', 'runs', 0]; //titile
const navigation_browse = ['navigationEndpoint', 'browseEndpoint'];
const page_type = [
  'browseEndpointContextSupportedConfigs',
  'browseEndpointContextMusicConfig',
  'pageType'
];
const navigation_watch_playlist_id = [
  'navigationEndpoint',
  'watchPlaylistEndpoint',
  'playlistId'
];
const audio_watch_playlist_id = [
  ...menu_items,
  0,
  'menuNavigationItemRenderer',
  ...navigation_watch_playlist_id
];
const title_text = ['title', 'runs', 0, 'text'];
const thumbnail_renderer = [
  'thumbnailRenderer',
  'musicThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];
const navigation_playlist_id = [
  'navigationEndpoint',
  'watchEndpoint',
  'playlistId'
];
const navigation_video_id = ['navigationEndpoint', 'watchEndpoint', 'videoId'];
const subtitle2 = ['subtitle', 'runs', 2, 'text'];
const navigation_browse_id = [
  'navigationEndpoint',
  'browseEndpoint',
  'browseId'
];

const text_run_navigation_browse_id = [];

const subtitle_badge_label = [
  'subtitleBadges',
  0,
  'musicInlineBadgeRenderer',
  'accessibilityData',
  'accessibilityData',
  'label'
];
const text_run_text = ['text', 'runs', 0, 'text'];
const text_run = ['text', 'runs', 0];
const badge_label = [
  'badges',
  0,
  'musicInlineBadgeRenderer',
  'accessibilityData',
  'accessibilityData',
  'label'
];
const thumbnail = ['thumbnail', 'thumbnails'];
const thumbnails = [
  'thumbnail',
  'musicThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];

const navigation_video_type = [
  'watchEndpoint',
  'watchEndpointMusicSupportedConfigs',
  'watchEndpointMusicConfig',
  'musicVideoType'
];
const toggle_menu = 'toggleMenuServiceItemRenderer';
const List<dynamic> menu_items = ['menu', 'menuRenderer', 'items'];
const menu_service = ['menuServiceItemRenderer', 'serviceEndpoint'];
const play_button = [
  'overlay',
  'musicItemThumbnailOverlayRenderer',
  'content',
  'musicPlayButtonRenderer'
];
const menu_like_status = [
  'menu',
  'menuRenderer',
  'topLevelButtons',
  0,
  'likeButtonRenderer',
  'likeStatus'
];
const List<dynamic> section_list_item = ['sectionListRenderer', 'contents', 0];
const List<dynamic> thumnail_cropped = [
  'thumbnail',
  'croppedSquareThumbnailRenderer',
  'thumbnail',
  'thumbnails'
];
const subtitle = ['subtitle', 'runs', 0, 'text'];
const subtitle3 = ['subtitle', 'runs', 4, 'text'];
const feedback_token = ['feedbackEndpoint', 'feedbackToken'];
const musicPlaylistShelfRenderer = [
  "contents",
  "twoColumnBrowseResultsRenderer",
  "secondaryContents",
  "sectionListRenderer",
  "contents",
  0,
  "musicPlaylistShelfRenderer",
];

List<Map<String, dynamic>> parseMixedContent(List<dynamic> rows) {
  List<Map<String, dynamic>> items = [];

  for (var row in rows) {
    if (row is! Map || row.isEmpty) continue;
    dynamic title;
    dynamic contents = [];
    final firstKey = row.keys.first.toString();
    if (description_shelf[0] == firstKey) {
      var results = nav(row, description_shelf);
      title = nav(results, ['header', 'runs', 0, 'text']);
      contents = nav(results, description);
    } else {
      var results = row.values.first;
      if (results is! Map || !results.containsKey('contents')) {
        continue;
      }
      title = nav(results, carousel_title + ['text']);

      final rawContents = results['contents'];
      if (rawContents is! List) continue;

      for (var result in rawContents) {
        if (result is! Map) continue;
        var data = nav(result, [mtrir]);
        dynamic content;
        if (data != null && data is Map) {
          var pageType = nav(data, n_title + navigation_browse + page_type,
              noneIfAbsent: true, funName: "mixed1");
          if (pageType == null) {
            if (nav(data, navigation_watch_playlist_id) != null) {
              //  content = parseWatchPlaylistHome(data);
            } else {
              content = parseSong(data);
            }
          } else if (pageType == "MUSIC_PAGE_TYPE_ALBUM") {
            content = parseAlbum(data, reqAlbumObj: false);
          } else if (pageType == "MUSIC_PAGE_TYPE_ARTIST") {
            content = parseRelatedArtist(Map<String, dynamic>.from(data));
          } else if (pageType == "MUSIC_PAGE_TYPE_PLAYLIST") {
            content = parsePlaylist(Map<String, dynamic>.from(data));
          }
        } else {
          data = nav(result, [mrlir]);
          if (data != null && data is Map) {
            content = parseSongFlat(Map<String, dynamic>.from(data));
          } else {
            content = null;
          }
        }

        if (content != null) {
          contents.add(content);
        }
      }

      items.add({'title': title, 'contents': contents});
    }
  }
  return items;
}

dynamic parseVideo(dynamic result) {
  if (result is! Map) return null;
  final runs = nav(result, ['subtitle', 'runs']);
  final runsLength = runs is List ? runs.length : 0;
  final rawSeparator = runs is List ? getDotSeparatorIndex(runs) : 0;
  final artistsLen = runsLength == 3 ? 1 : (rawSeparator > 0 ? rawSeparator : 0);
  final artistsRuns = (runs is List && artistsLen > 0 && runs.length >= artistsLen)
      ? runs.sublist(0, artistsLen)
      : <dynamic>[];
  String views = "";
  if (runs is List && runs.isNotEmpty) {
    final lastItem = runs[runs.length - 1];
    if (lastItem is Map && lastItem['text'] != null) {
      views = lastItem['text'].toString().split(' ')[0];
    }
  }
  return MediaItemBuilder.fromJson({
    'title': nav(result, title_text),
    'videoId': nav(result, navigation_video_id) ??
        nav(
          result,
          navigation_browse_id,
        ),
    'artists': parseSongArtistsRuns(artistsRuns),
    'playlistId': nav(result, navigation_playlist_id),
    'thumbnails': nav(result, thumbnail_renderer),
    'views': views,
  });
}

dynamic parseSingle(dynamic result) {
  if (result is! Map) return null;
  dynamic year;
  try {
    year = int.parse(nav(result, subtitle)?.toString() ?? "");
  } catch (e) {
    year = nav(result, ["subtitle", "runs", 2, "text"]);
  }
  final subRuns = nav(result, ["subtitle", "runs"]);
  final desc = (subRuns is List)
      ? subRuns
          .map((run) => (run is Map ? run['text']?.toString() : null) ?? '')
          .join('')
      : '';
  return Album.fromJson({
    'title': nav(result, title_text),
    'artists': [
      {'name': 'Single'}
    ],
    'audioPlaylistId': nav(result, audio_watch_playlist_id),
    'year': "${year ?? ""}",
    'browseId': nav(result, ['title', 'runs', 0, ...navigation_browse_id]),
    'thumbnails': nav(result, thumbnail_renderer),
    'description': desc,
  });
}

MediaItem parseSong(Map<dynamic, dynamic> result) {
  var song = {
    'title': nav(result, title_text),
    'videoId':
        nav(result, navigation_video_id) ?? nav(result, navigation_browse_id),
    'playlistId': nav(result, navigation_playlist_id,
        noneIfAbsent: true, funName: "parseSong"),
    'thumbnails': nav(result, thumbnail_renderer),
  };

  final runs = nav(result, ['subtitle', 'runs']);
  if (runs is List) {
    song.addAll(parseSongRuns(runs));
  }
  return MediaItemBuilder.fromJson(song);
}

Map<String, dynamic> parseSongRuns(List<dynamic>? runs) {
  Map<String, dynamic> parsed = {'artists': []};
  if (runs == null) return parsed;
  for (int i = 0; i < runs.length; i++) {
    final rawRun = runs[i];
    if (rawRun is! Map) continue;
    Map<String, dynamic> run = Map<String, dynamic>.from(rawRun);
    if (i % 2 != 0) {
      // uneven items are always separators
      continue;
    }
    String text = run['text']?.toString() ?? '';
    if (run.containsKey('navigationEndpoint')) {
      // artist or album
      Map<String, dynamic> item = {
        'name': text,
        'id': nav(run, navigation_browse_id,
            noneIfAbsent: true, funName: "parseSongRuns")
      };

      if (item['id'] != null &&
          (item['id'].toString().startsWith('MPRE') ||
              item['id'].toString().contains("release_detail"))) {
        // album
        parsed['album'] = item;
      } else {
        // artist
        parsed['artists'].add(item);
      }
    } else {
      RegExp regExp = RegExp(r"^\d([^ ])* [^ ]*$");
      if (regExp.hasMatch(text) && i > 0) {
        parsed['views'] = text.split(' ')[0];
      } else if (RegExp(r"^(\d+:)*\d+:\d+$").hasMatch(text)) {
        parsed['length'] = text;
        parsed['duration_seconds'] = parseDuration(text);
      } else if (RegExp(r"^\d{4}$").hasMatch(text)) {
        parsed['year'] = text;
      } else {
        // artist without id
        parsed['artists'].add({'name': text, 'id': null});
      }
    }
  }
  return parsed;
}

Album parseAlbum(Map<dynamic, dynamic> result, {bool reqAlbumObj = true}) {
  final runs = nav(result, ['subtitle', 'runs']);
  final Map<String, dynamic> artistInfo =
      runs is List ? parseSongRuns(runs) : {'artists': []};
  final desc = (runs is List)
      ? runs
          .map((run) => (run is Map ? run['text']?.toString() : null) ?? '')
          .join('')
      : '';
  Map albumMap = {
    'title': nav(result, title_text),
    'browseId': nav(result, n_title + navigation_browse_id),
    'thumbnails': nav(result, thumbnail_renderer),
    'audioPlaylistId': nav(result, audio_watch_playlist_id),
    'description': desc,
  };
  albumMap.addAll(artistInfo);
  return Album.fromJson(albumMap);
}

Artist parseRelatedArtist(Map<String, dynamic> data) {
  return Artist.fromJson({
    'artist': nav(data, title_text),
    'browseId': nav(data, n_title + navigation_browse_id),
    'thumbnails': nav(data, thumbnail_renderer),
  });
}

Playlist parsePlaylist(Map<String, dynamic> data) {
  Map<String, dynamic> playlist = {
    'title': nav(data, title_text),
    'playlistId': nav(data, ['title', 'runs', 0] + navigation_browse_id),
    'thumbnails': nav(data, thumbnail_renderer)
  };

  var subtitle = data['subtitle'];
  if (subtitle is Map && subtitle.containsKey('runs') && subtitle['runs'] is List) {
    var runs = subtitle['runs'] as List;
    playlist['description'] = runs
        .map((run) => (run is Map ? run['text']?.toString() : null) ?? '')
        .join('');
    if (runs.length == 3 && RegExp(r'\d+ ').hasMatch(nav(data, subtitle2)?.toString() ?? '')) {
      playlist['count'] = nav(data, subtitle2).toString().split(' ')[0];
      playlist['author'] = parseSongArtistsRuns(runs.sublist(0, 1));
    }
  }

  return Playlist.fromJson(playlist);
}

List<dynamic> parseSongArtistsRuns(List<dynamic>? runs) {
  if (runs == null || runs.isEmpty) return [];
  List<Map<String, dynamic>> artists = [];
  int n = (runs.length / 2).floor() + 1;
  for (var j = 0; j < n; j++) {
    final idx = j * 2;
    if (idx < runs.length && runs[idx] is Map) {
      final runMap = runs[idx] as Map;
      artists.add({
        'name': runMap['text']?.toString() ?? '',
        'id': nav(runMap, navigation_browse_id,
            noneIfAbsent: false, funName: "parseSongArtistsRuns"),
      });
    }
  }
  return artists;
}

MediaItem parseSongFlat(Map<String, dynamic> data) {
  //print(data);
  List<Map<String, dynamic>> columns = [];
  for (int i = 0; i < data['flexColumns'].length; i++) {
    columns.add(getFlexColumnItem(data, i));
  }

  Map<String, dynamic> song = {
    'title': nav(columns[0], text_run_text),
    'videoId': nav(columns[0], text_run + navigation_video_id,
            noneIfAbsent: true, funName: "parseSongFlat") ??
        nav(columns[0], text_run + navigation_browse_id,
            noneIfAbsent: true, funName: "parseSongFlat"),
    'artists': parseSongArtists(data, 1),
    'thumbnails': nav(data, thumbnails),
    //'isExplicit': nav(data, badge_label, noneIfAbsent: true) != null
  };
//checkpoint .contains
  if (columns.length > 2 && columns[2].isNotEmpty) {
    final tr = nav(columns[2], text_run);
    if (tr is Map && tr.containsKey('navigationEndpoint')) {
      song['album'] = {
        'name': nav(columns[2], text_run_text),
        'id': nav(columns[2], text_run + navigation_browse_id)
      };
    }
  }

  return MediaItemBuilder.fromJson(song);
}

List<dynamic>? parseSongArtists(Map<String, dynamic> data, int index) {
  dynamic flexItem = getFlexColumnItem(data, index);
  if (flexItem is! Map || flexItem.isEmpty) {
    return null;
  } else {
    final runs = nav(flexItem, ['text', 'runs']);
    return runs is List ? parseSongArtistsRuns(runs) : null;
  }
}

Map<String, dynamic> getFlexColumnItem(Map<String, dynamic> item, int index) {
  if (item['flexColumns'] is! List ||
      (item['flexColumns'] as List).length <= index) {
    return {};
  }
  final col = item['flexColumns'][index];
  if (col is! Map ||
      col['musicResponsiveListItemFlexColumnRenderer'] is! Map) {
    return {};
  }
  final renderer = col['musicResponsiveListItemFlexColumnRenderer'] as Map<String, dynamic>;
  if (!renderer.containsKey('text') || renderer['text'] is! Map) {
    return {};
  }
  final textMap = renderer['text'] as Map;
  if (!textMap.containsKey('runs') || textMap['runs'] is! List) {
    return {};
  }

  return renderer;
}

Map<String, dynamic> parseWatchPlaylistHome(Map<dynamic, dynamic> data) {
  return {
    'title': nav(data, title_text),
    'playlistId': nav(data, navigation_watch_playlist_id),
    'thumbnails': nav(data, thumbnail_renderer),
  };
}

//For Song Watch Playlist

List<dynamic> parseWatchPlaylist(List<dynamic> results) {
  final tracks = [];
  const PPVWR = 'playlistPanelVideoWrapperRenderer';
  const PPVR = 'playlistPanelVideoRenderer';
  for (var result in results) {
    if (result is! Map) continue;
    Map<String, dynamic>? counterpart;
    if (result.containsKey(PPVWR) && result[PPVWR] is Map) {
      final cpList = result[PPVWR]['counterpart'];
      if (cpList is List && cpList.isNotEmpty && cpList[0] is Map) {
        final cpRenderer = cpList[0]['counterpartRenderer'];
        if (cpRenderer is Map && cpRenderer[PPVR] is Map) {
          counterpart = Map<String, dynamic>.from(cpRenderer[PPVR]);
        }
      }
      result = result[PPVWR]['primaryRenderer'] ?? result;
    }
    if (result is! Map || !result.containsKey(PPVR) || result[PPVR] is! Map) {
      continue;
    }
    final data = result[PPVR] as Map;
    if (data.containsKey('unplayableText')) {
      continue;
    }
    final track = parseWatchTrack(Map<String, dynamic>.from(data));
    if (counterpart != null) {
      track['counterpart'] = parseWatchTrack(counterpart);
    }
    tracks.add(MediaItemBuilder.fromJson(track));
  }
  return tracks;
}

Map<String, dynamic> parseWatchTrack(Map<String, dynamic> data) {
  final runs = nav(data, ['longBylineText', 'runs']);
  final songInfo = runs is List ? parseSongRuns(runs) : {'artists': []};

  final track = {
    'videoId': data['videoId']?.toString(),
    'title': nav(data, title_text),
    'length': nav(data, ['lengthText', 'runs', 0, 'text']),
    'thumbnails': nav(data, thumbnail),
    'videoType': nav(data, ['navigationEndpoint'] + navigation_video_type),
  };
  track.addAll(songInfo);
  return track;
}

String? getTabBrowseId(dynamic watchNextRenderer, int tabId) {
  try {
    if (watchNextRenderer is! Map) return null;
    final tabs = watchNextRenderer['tabs'] as List?;
    if (tabs != null && tabId < tabs.length) {
      final tabRenderer = tabs[tabId]?['tabRenderer'] as Map?;
      if (tabRenderer != null && !tabRenderer.containsKey('unselectable')) {
        final endpoint = tabRenderer['endpoint'] as Map?;
        final browseEndpoint = endpoint?['browseEndpoint'] as Map?;
        return browseEndpoint?['browseId']?.toString();
      }
    }
  } catch (_) {}
  return null;
}

///Parse playlist songs, Also used in Album Song parsing
///
///[dynamic album,dynamic artists] used in Album case
List<dynamic> parsePlaylistItems(List<dynamic> results,
    {List<List<dynamic>>? menuEntries,
    dynamic thumbnailsM,
    dynamic artistsM,
    String? albumYear,
    dynamic albumIdName,
    bool isAlbum = false}) {
  List<MediaItem> songs = [];

  //int count = 1;
  for (dynamic result in results) {
    // count += 1;
    if (result is! Map || !result.containsKey('musicResponsiveListItemRenderer')) {
      continue;
    }
    dynamic data = result['musicResponsiveListItemRenderer'];
    if (data is! Map) continue;
    String? videoId;
    String? trackDetails;

    videoId = nav(data, ['playlistItemData', 'videoId']);

    if (videoId == null && isAlbum) {
      final creditId = nav(data, [
        'menu',
        'menuRenderer',
        'items',
        5,
        'menuNavigationItemRenderer',
        'navigationEndpoint',
        'browseEndpoint',
        'browseId'
      ])?.toString();
      if (creditId != null && creditId.contains("MPTC")) {
        final parts = creditId.split("MPTC");
        if (parts.length > 1) {
          videoId = parts[1];
        }
      }
      
    }

    if(isAlbum){
      // Contains track number and total tracks 
      trackDetails = data["index"] != null
          ? "${nav(data, ['index', 'runs', 0, 'text'])}/${results.length}"
          : null;
    }

    // if the item has a menu, find its setVideoId
    if (videoId == null) {
      if (data.containsKey('menu')) {
        final menuItems = nav(data, menu_items);
        if (menuItems is Iterable) {
          for (dynamic item in menuItems) {
            if (item is Map && item.containsKey('menuServiceItemRenderer')) {
              dynamic menuService = nav(item, menu_service);
              if (menuService is Map && menuService.containsKey('playlistEditEndpoint')) {
                final actions = menuService['playlistEditEndpoint']?['actions'];
                if (actions is List && actions.isNotEmpty && actions[0] is Map) {
                  videoId = actions[0]['removedVideoId']?.toString();
                }
              }
            }
          }
        }
      }
    }

    // if item is not playable, the videoId was retrieved above
    if (videoId == null && nav(data, play_button) != null) {
      final pb = nav(data, play_button);
      if (pb is Map && pb.containsKey('playNavigationEndpoint')) {
        videoId = pb['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
      }
    }

    final dataMap = Map<String, dynamic>.from(data);
    String? title = getItemText(dataMap, 0);
    if (title == 'Song deleted') {
      continue;
    }

    List? artists = parseSongArtists(dataMap, 1);

    dynamic album = isAlbum ? albumIdName : parseSongAlbum(dataMap, 2);

    dynamic duration;
    if (data.containsKey('fixedColumns')) {
      final fixedCol = getFixedColumnItem(dataMap, 0);
      if (fixedCol != null &&
          fixedCol.isNotEmpty &&
          fixedCol.containsKey('text') &&
          fixedCol['text'] is Map) {
        final textObj = fixedCol['text'] as Map;
        if (textObj.containsKey('simpleText')) {
          duration = textObj['simpleText'];
        } else if (textObj['runs'] is List && (textObj['runs'] as List).isNotEmpty) {
          duration = textObj['runs'][0]?['text'];
        }
      }
    }
    if (duration == null && data.containsKey('flexColumns')) {
      final reg = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');
      for (final col in data['flexColumns']) {
        final runs = nav(col, [
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs'
        ]) as List?;
        if (runs != null) {
          for (final run in runs) {
            final t = run['text']?.toString().trim();
            if (t != null && reg.hasMatch(t)) {
              duration = t;
              break;
            }
          }
        }
        if (duration != null) break;
      }
    }

    dynamic thumbnails_;
    if (data.containsKey('thumbnail')) {
      thumbnails_ = nav(data, thumbnails);
    }

    bool isAvailable = true;
    if (data.containsKey('musicItemRendererDisplayPolicy')) {
      isAvailable = data['musicItemRendererDisplayPolicy'] !=
          'MUSIC_ITEM_RENDERER_DISPLAY_POLICY_GREY_OUT';
    }

    //print('here');
    dynamic song = {
      'videoId': videoId,
      'title': title,
      'album': album,
      'artists': artists ?? artistsM,
      'thumbnails': isAlbum ? thumbnailsM : thumbnails_ ?? thumbnailsM,
      'isAvailable': isAvailable,
      'trackDetails': trackDetails
    };

    if (duration != null) {
      song['length'] = duration;
      song['duration_seconds'] = parseDuration(duration);
    }

    if (menuEntries != null) {
      for (final List<dynamic> menuEntry in menuEntries) {
        song[menuEntry.last] = nav(data,
            menu_items + menuEntry.map((e) => e).whereType<String>().toList());
      }
    }
    if (song['videoId'] != null) {
      songs.add(MediaItemBuilder.fromJson(song));
    }
  }
  return songs;
}

Map<String, dynamic>? parseSongAlbum(Map<String, dynamic> data, int index) {
  Map<String, dynamic> flexItem = getFlexColumnItem(data, index);
  // print("here");
  if (flexItem.isNotEmpty) {
    return {
      'name': getItemText(data, index),
      'id': getBrowseId(flexItem, 0),
    };
  }
  return null;
}

String? getBrowseId(Map<String, dynamic> item, int index) {
  if (item['text']['runs'][index].containsKey('navigationEndpoint')) {
    return nav(item['text']['runs'][index], navigation_browse_id);
  }
  return null;
}

Map<String, dynamic> parseSongMenuTokens(Map<String, dynamic> item) {
  Map<String, dynamic> toggleMenu = item[toggle_menu];
  String serviceType = toggleMenu['defaultIcon']['iconType'];
  Map<String, dynamic> libraryAddToken =
      nav(toggleMenu, ['defaultServiceEndpoint', ...feedback_token]);
  Map<String, dynamic> libraryRemoveToken =
      nav(toggleMenu, ['toggledServiceEndpoint', ...feedback_token]);

  if (serviceType == "LIBRARY_REMOVE") {
    // swap if already in library
    Map<String, dynamic> temp = libraryAddToken;
    libraryAddToken = libraryRemoveToken;
    libraryRemoveToken = temp;
  }

  return {'add': libraryAddToken, 'remove': libraryRemoveToken};
}

dynamic nav(dynamic root, List items,
    {bool noneIfAbsent = false, String funName = "d"}) {
  try {
    dynamic res = root;
    for (final item in items) {
      res = res[item];
    }
    return res;
  } catch (e) {
    return null;
  }
}

//search parsers
dynamic parseTopResult(
    Map<String, dynamic> data, List<String> searchResultTypes) {
  Map<String, dynamic> searchResult = {};
  String? resultType =
      getSearchResultType(nav(data, subtitle), searchResultTypes);
  searchResult['resultType'] = resultType;

  if (resultType == 'artist') {
    String? subscribers = nav(data, subtitle2);
    if (subscribers != null) {
      searchResult['subscribers'] = subscribers.split(' ')[0];
    }
    Map<String, dynamic> artistInfo =
        parseSongRuns(nav(data, ['title', 'runs']));
    searchResult.addAll(artistInfo);
  }

  if (resultType == 'song' || resultType == 'video' || resultType == 'album') {
    searchResult['title'] = nav(data, title_text);
    final runs = nav(data, ['subtitle', 'runs']);
    if (runs is List) {
      List songInfoRuns = runs.length >= 2 ? runs.sublist(2) : runs;
      Map<String, dynamic> songInfo = parseSongRuns(songInfoRuns);
      searchResult.addAll(songInfo);
    }
  }

  searchResult['thumbnails'] = nav(data, thumbnails);

  if (resultType == 'song' || resultType == 'video') {
    return MediaItemBuilder.fromJson(searchResult);
  } else if (resultType == 'playlist') {
    return Playlist.fromJson(searchResult);
  } else if (resultType == 'album') {
    return Album.fromJson(searchResult);
  } else if (resultType == 'Artist') {
    return Artist.fromJson(searchResult);
  }
  return searchResult;
}

String? getSearchResultType(
    String? resultTypeLocal, List<String> resultTypesLocal) {
  if (resultTypeLocal == null) {
    return null;
  }
  List<String> resultTypes = ['artist', 'playlist', 'song', 'video', 'station'];
  resultTypeLocal = resultTypeLocal.toLowerCase();
  if (!resultTypesLocal.contains(resultTypeLocal)) {
    return 'album';
  } else {
    int index = resultTypesLocal.indexOf(resultTypeLocal);
    return resultTypes[index];
  }
}

List<dynamic> parseSearchResults(List<dynamic> results,
    List<String> searchResultTypes, String? resultType, String category) {
  return results
      .map((result) {
        if (result == null ||
            result is! Map ||
            result['musicResponsiveListItemRenderer'] == null) {
          return null;
        }
        return parseSearchResult(result['musicResponsiveListItemRenderer'],
            searchResultTypes, resultType, category);
      })
      .where((e) => e != null)
      .toList();
}

dynamic parseSearchResult(Map<String, dynamic> data,
    List<String> searchResultTypes, String? resultType, String? category) {
  if ((resultType != null && resultType.contains("playlist")) ||
      (category != null && category.contains("playlists"))) {
    resultType = 'playlist';
  }
  int defaultOffset = (resultType == null) ? 2 : 0;
  Map<String, dynamic> searchResult = {'category': category};
  String? videoType = nav(data,
      [...play_button, 'playNavigationEndpoint', ...navigation_video_type]);
  if (videoType != null) {
    resultType = (videoType == 'MUSIC_VIDEO_TYPE_ATV') ? 'song' : 'video';
  }

  resultType = ((resultType == null)
      ? (getSearchResultType(getItemText(data, 1), searchResultTypes) ?? 'song')
      : resultType);
  searchResult['resultType'] = resultType;

  if (resultType != 'artist') {
    searchResult['title'] = getItemText(data, 0);
  }

  if (resultType == 'artist') {
    searchResult['artist'] = getItemText(data, 0);
    final runs = nav(data, [
      'flexColumns',
      1,
      'musicResponsiveListItemFlexColumnRenderer',
      'text',
      'runs'
    ]);
    if (runs is List && runs.length > 2 && runs[2] is Map) {
      searchResult['subscribers'] = runs[2]['text']?.toString() ?? "";
    } else {
      searchResult['subscribers'] = "";
    }
  } else if (resultType == 'album') {
    searchResult['type'] = getItemText(data, 1);
    searchResult['audioPlaylistId'] = nav(data, audio_watch_playlist_id);
    try {
      final runs = nav(data, [
        'flexColumns',
        1,
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
        'runs'
      ]);
      if (runs is List) {
        searchResult['description'] =
            runs.map((run) => (run is Map ? run['text']?.toString() : null) ?? '').join('');
      }
    } catch (e) {}
  } else if (resultType.contains('playlist')) {
    final flexItemMap = getFlexColumnItem(data, 1);
    final runs = nav(flexItemMap, ['text', 'runs']);
    if (runs is List) {
      bool hasAuthor = (runs.length == defaultOffset + 3);
      final countText = nav(runs, [defaultOffset + (hasAuthor ? 2 : 0), 'text'])?.toString();
      if (countText != null) {
        searchResult['itemCount'] = countText.split(' ')[0];
      }
      searchResult['description'] =
          hasAuthor ? nav(runs, [defaultOffset, 'text'])?.toString() : null;
    }
  } else if (resultType == 'station') {
    searchResult['videoId'] =
        nav(data, navigation_video_id) ?? nav(data, navigation_browse_id);
    searchResult['playlistId'] = nav(data, navigation_playlist_id);
  } else if (resultType == 'song') {
    searchResult['album'] = null;
  } else if (resultType == 'upload') {
    String? browseId = nav(data, navigation_browse_id);
    if (browseId == null) {
      List<dynamic> flexItems = [
        nav(getFlexColumnItem(data, 0), ['text', 'runs']),
        nav(getFlexColumnItem(data, 1), ['text', 'runs'])
      ];
      if (flexItems[0] != null) {
        searchResult['videoId'] = nav(flexItems[0][0], navigation_video_id) ??
            nav(flexItems[0][0], navigation_browse_id);
        searchResult['playlistId'] =
            nav(flexItems[0][0], navigation_playlist_id);
      }
      if (flexItems[1] != null) {
        searchResult.addAll(parseSongRuns(flexItems[1]));
      }
      searchResult['resultType'] = 'song';
    } else {
      searchResult['browseId'] = browseId;
      if (searchResult['browseId'].contains('artist')) {
        searchResult['resultType'] = 'artist';
      } else {
        Map<String, dynamic> flexItem2 = getFlexColumnItem(data, 1);
        final flexRuns = nav(flexItem2, ['text', 'runs']);
        List<dynamic> runs = [];
        if (flexRuns is List) {
          for (int i = 0; i < flexRuns.length; i++) {
            if (i % 2 == 0 && flexRuns[i] is Map) {
              runs.add(flexRuns[i]['text']?.toString() ?? '');
            }
          }
        }
        if (runs.length > 1) {
          searchResult['artist'] = runs[1];
        }
        if (runs.length > 2) {
          searchResult['releaseDate'] = runs[2];
        }
        searchResult['resultType'] = 'album';
      }
    }
  }
  if ((['song', 'video']).contains(resultType)) {
    searchResult['videoId'] = nav(data,
        [...play_button, 'playNavigationEndpoint', 'watchEndpoint', 'videoId']);
    searchResult['videoType'] = videoType;
  }

  if ((['song', 'video', 'album']).contains(resultType)) {
    searchResult['length'] = null;
    searchResult['year'] = null;
    final flexItem = getFlexColumnItem(data, 1);
    final runs = nav(flexItem, ['text', 'runs']);
    if (runs is List) {
      final songInfo = parseSongRuns(runs);
      searchResult.addAll(songInfo);
    }
  }

  if ((['artist', 'album', 'playlist']).contains(resultType)) {
    searchResult['browseId'] = nav(data, navigation_browse_id);
    if (searchResult['browseId'] == null) {
      return {};
    }
  }

  if ((['song', 'album']).contains(resultType)) {
    searchResult['isExplicit'] = nav(data, badge_label);
  }

  searchResult['thumbnails'] = nav(data, thumbnails);

  if (resultType == 'song' || resultType == 'video') {
    if (searchResult['videoId'] != null) {
      return MediaItemBuilder.fromJson(searchResult);
    }
    return;
  } else if (resultType.contains('playlist')) {
    return Playlist.fromJson(searchResult);
  } else if (resultType == 'album') {
    return Album.fromJson(searchResult);
  } else if (resultType == 'artist') {
    return Artist.fromJson(searchResult);
  }

  return searchResult;
}

//parse album Header
Map<String, dynamic> parseAlbumHeader(Map<String, dynamic> response) {
  Map<String, dynamic> header = nav(response, [
        'contents',
        "twoColumnBrowseResultsRenderer",
        'tabs',
        0,
        "tabRenderer",
        "content",
        "sectionListRenderer",
        "contents",
        0,
        "musicResponsiveHeaderRenderer"
      ]) ??
      nav(response, ["header", "musicDetailHeaderRenderer"]) ??
      {};
  Map<String, dynamic> album = {
    'title': nav(header, title_text),
    'type': nav(header, subtitle),
    'thumbnails': nav(header, thumnail_cropped) ??
        nav(header,
            ["thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails"])
  };

  final descShelf = nav(header, [
    "description",
    "musicDescriptionShelfRenderer",
    "description",
    "runs",
    0,
    "text"
  ]);
  if (descShelf != null) {
    album["description"] = descShelf;
  } else {
    final subRuns = nav(header, ["subtitle", "runs"]);
    if (subRuns is List) {
      album["description"] = subRuns
          .map((item) => item is Map && item.values.isNotEmpty ? item.values.first?.toString() : '')
          .toList()
          .join(" ");
    }
  }

  final subRuns = nav(header, ['subtitle', 'runs']);
  if (subRuns is List) {
    final subList = subRuns.length >= 2 ? subRuns.sublist(2) : subRuns;
    Map<String, dynamic> albumInfo = parseSongRuns(subList);
    try {
      final strapRuns = nav(header, ["straplineTextOne", 'runs']);
      if (strapRuns is List) {
        albumInfo.addAll(parseSongRuns(strapRuns));
      }
    } catch (e) {}
    album.addAll(albumInfo);
  }

  final secRuns = nav(header, ['secondSubtitle', 'runs']);
  if (secRuns is List && secRuns.isNotEmpty) {
    if (secRuns.length > 2 && secRuns[2] is Map) {
      album['trackCount'] = secRuns[0]?['text']?.toString();
      album['duration'] = secRuns[2]?['text']?.toString();
    } else {
      album['duration'] = secRuns[0]?['text']?.toString();
    }
  }

  // add to library/uploaded
  final canonUrl = nav(response, ['microformat', "microformatDataRenderer", "urlCanonical"])?.toString();
  if (canonUrl != null && canonUrl.contains("list=")) {
    final parts = canonUrl.split("list=");
    if (parts.length > 1) {
      album['audioPlaylistId'] = parts[1];
    }
  }

  return album;
}

Map<String, dynamic> parseArtistContents(List results) {
  final Map<String, dynamic> navigationEndpointsNContent = {
    'Songs': null,
    'Videos': null,
    'Albums': null,
    'Singles': null
  };

  for (dynamic result in results) {
    if (result is! Map) continue;
    if (result.containsKey('musicShelfRenderer')) {
      final title =
          nav(result, ['musicShelfRenderer', 'title', 'runs', 0])?['text'];
      final browseEndpoint = nav(
          result, ['musicShelfRenderer', 'bottomEndpoint', 'browseEndpoint']);

      final contentList = nav(result, ['musicShelfRenderer', 'contents']);
      final content = contentList is List ? parsePlaylistItems(contentList) : [];

      if (title != null) {
        if (browseEndpoint == null) {
          navigationEndpointsNContent[title] = {"content": content};
        } else {
          navigationEndpointsNContent[title] = {
            'browseId': browseEndpoint['browseId'],
            'params': browseEndpoint['params'],
            "content": content
          };
        }
      }
    } else if (result.containsKey('musicCarouselShelfRenderer')) {
      final browseEndpoint = nav(result, [
        'musicCarouselShelfRenderer',
        'header',
        'musicCarouselShelfBasicHeaderRenderer',
        'moreContentButton',
        'buttonRenderer',
        'navigationEndpoint',
        'browseEndpoint'
      ]);

      final title = nav(result, [
        'musicCarouselShelfRenderer',
        'header',
        'musicCarouselShelfBasicHeaderRenderer',
        'title',
        'runs',
        0
      ])?['text'];

      final contentList =
          nav(result, ['musicCarouselShelfRenderer', 'contents']);
      dynamic content = [];
      if (contentList is List) {
        if (title == "Videos") {
          content = contentList
              .map((video) => video is Map ? parseVideo(video['musicTwoRowItemRenderer']) : null)
              .where((e) => e != null)
              .toList();
        } else if (title == "Albums") {
          content = contentList
              .map((album) => album is Map ? parseAlbum(album['musicTwoRowItemRenderer']) : null)
              .where((e) => e != null)
              .toList();
        } else if (title == "Singles") {
          content = contentList
              .map((single) => single is Map ? parseSingle(single['musicTwoRowItemRenderer']) : null)
              .where((e) => e != null)
              .toList();
        }
      }

      if (title != null) {
        if (browseEndpoint != null) {
          navigationEndpointsNContent[title] = {
            'browseId': browseEndpoint['browseId'],
            'params': browseEndpoint['params'],
            'content': content
          };
        } else {
          navigationEndpointsNContent[title] = {'content': content};
        }
      }
    }
  }
  return navigationEndpointsNContent;
}

dynamic parseContentList(results, Function parseFunc) {
  var contents = [];
  if (results is! Iterable) return contents;
  for (dynamic result in results) {
    if (result is Map) {
      contents.add(parseFunc(result['musicTwoRowItemRenderer']));
    }
  }

  return contents;
}

Map<String, dynamic> parseChartsItemBrowseId(dynamic result) {
  final title = nav(result,["musicTwoRowItemRenderer","title","runs",0,"text"])?.toString() ?? "";
  final browseId = nav(result,
      ["musicTwoRowItemRenderer","title","runs",0,"navigationEndpoint","browseEndpoint","browseId"]);
  if (title.contains('Trending')) {
    return {'title': "Trending", 'browseId': browseId};
  } else if (title.contains('Daily Top')) {
    return {'title': "Top Music Videos", 'browseId': browseId};
  }
  else{
    return {'title': title, 'browseId': browseId};
  }
}

Map<String, dynamic> parseChartsItem(dynamic result) {
  final contentList = nav(result, ['musicCarouselShelfRenderer', 'contents']);
  if (contentList is! List) return {};
  final String category = nav(result, [
    'musicCarouselShelfRenderer',
    'header',
    'musicCarouselShelfBasicHeaderRenderer',
    'title',
    ...run_text
  ])?.toString() ?? "";
  if (category.contains('videos')) {
    final videoList = contentList
        .map((video) => video is Map ? parseVideo(video['musicTwoRowItemRenderer']) : null)
        .where((e) => e != null)
        .toList();
    return {'title': category, 'contents': videoList};
  } else if (category.contains('artists')) {
    final artists = contentList
        .map((artist) =>
            artist is Map ? parseChartsArtist(artist['musicResponsiveListItemRenderer']) : null)
        .where((e) => e != null)
        .toList();
    return {'title': category, 'contents': artists};
  } else if (category.contains('Genres')) {
    final playlists = contentList
        .map((playlist) => playlist is Map ? parsePlaylist(playlist['musicTwoRowItemRenderer']) : null)
        .where((e) => e != null)
        .toList();
    return {'title': category, 'contents': playlists};
  } else if (category.contains('Trending')) {
    final videoList = contentList
        .map((video) =>
            video is Map ? parseChartsTrending(video['musicResponsiveListItemRenderer']) : null)
        .whereType<MediaItem>()
        .toList();
    return {'title': category, 'contents': videoList};
  }
  return {};
}

Artist parseChartsArtist(dynamic data) {
  if (data is! Map) {
    return Artist.fromJson({'artist': '', 'thumbnails': []});
  }
  final map = Map<String, dynamic>.from(data);
  final subscribers = getFlexColumnItem(map, 1);
  dynamic subs;
  if (subscribers.isNotEmpty) {
    subs = nav(subscribers, text_run_text)?.toString().split(' ')[0];
  }

  final parsed = {
    'artist': nav(getFlexColumnItem(map, 0), text_run_text),
    'browseId': nav(map, navigation_browse_id),
    'subscribers': subs,
    'thumbnails': nav(map, thumbnails),
  };

  return Artist.fromJson(parsed);
}

MediaItem? parseChartsTrending(dynamic data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final flex_0 = getFlexColumnItem(map, 0);
  final artists = parseSongArtists(map, 1);

  final video = {
    'title': nav(flex_0, text_run_text),
    'videoId': nav(
          flex_0,
          text_run + navigation_video_id,
        ) ??
        nav(map, ['playlistItemData', 'videoId']),
    'playlistId': nav(flex_0, text_run + navigation_playlist_id),
    'artists': artists,
    'thumbnails': nav(map, thumbnails),
  };
  if (video['videoId'] == null) {
    return null;
  }
  return MediaItemBuilder.fromJson(video);
}
