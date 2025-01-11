import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  final _title = 'Flutter SketchApp (Cupertino)';

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: _title,
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeGreen,
      ),
      home: MyStatefulWidget(),
    );
  }
}

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({Key? key}) : super(key: key);

  @override
  State<MyStatefulWidget> createState() => MyStatefulWidgetState();
}

class MyStatefulWidgetState extends State<MyStatefulWidget> {
  // 각 탭에서 보여줄 위젯
  final List<Widget> _tabs = <Widget>[
    SearchWidget(),
    HelloWidget(),
    StarWidget(),
  ];


  @override
  Widget build(BuildContext context) {
    // Cupertino 스타일의 탭 구조
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cloud),
            label: 'Hello',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.star),
            label: 'Star',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) {
            return _tabs[index];
          },
        );
      },
    );
  }
}

class StarWidget extends StatelessWidget {
  final Map info = {
    'titleImageLink': 'https://storage.googleapis.com/cms-storage-bucket/'
        '2f118a9971e4ca6ad737.png',
    'titleSectionHeader': 'Flutter on Mobile',
    'titleSectionBody': 'https://flutter.dev/multi-platform/mobile',
    'titleSectionScore': 100,
    'textSection': 'Bring your app idea to more users from day one '
        'by building with Flutter on iOS and Android simultaneously, '
        'without sacrificing features, quality, or performance. '
        '\n\nAll mobile on day one: Reach your full addressable market from '
        'day one by targeting users in both ecosystems from a single codebase. '
        '\n\nDo more with less: Unite your mobile development team resources '
        'towards building one seamless customer experience. '
        '\n\nOne experience: Release simultaneously on iOS and Android with '
        'feature parity for the best experience for all users.',
  };

  @override
  Widget build(BuildContext context) {
    final titleImage = _buildTitleImage(info['titleImageLink']);
    final textSection = _buildTextSection(info['textSection']);
    final buttonSection = _buildButtonSection(
      CupertinoTheme.of(context).primaryColor,
    );
    final titleSection = _buildTitleSection(
      info['titleSectionHeader'],
      info['titleSectionBody'],
      info['titleSectionScore'],
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // leading: CupertinoButton(child: Icon(Icons.arrow_back_ios), onPressed: (){}),
        middle: Text('Cupertino Design'),
        // trailing: CupertinoButton(child: Icon(Icons.exit_to_app), onPressed: (){}),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            titleImage,
            titleSection,
            buttonSection,
            textSection,
          ],
        ),
      ),
    );
  }
}

Image _buildTitleImage(String imageName) {
  return Image.network(
    imageName,
    width: 600,
    height: 240,
    fit: BoxFit.cover,
  );
}

Container _buildTitleSection(String name, String addr, int count) {
  return Container(
    padding: const EdgeInsets.all(32),
    child: Row(
      children: [
        // 텍스트 영역
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                addr,
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        // 좋아요 등 카운트 버튼 영역
        const Counter(),
      ],
    ),
  );
}

Widget _buildButtonSection(Color color) {
  // Cupertino에서는 일반적으로 CupertinoButton 또는 Icon + GestureDetector 조합 사용
  // 여기서는 간단히 CupertinoButton을 사용합니다.
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildCupertinoButtonColumn(color, CupertinoIcons.arrow_right_circle, 'Visit'),
      _buildCupertinoButtonColumn(color, CupertinoIcons.bell, 'Alarm'),
      _buildCupertinoButtonColumn(color, CupertinoIcons.share, 'Share'),
    ],
  );
}

Column _buildCupertinoButtonColumn(Color color, IconData icon, String label) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CupertinoButton(
        onPressed: () {
          // 동작을 정의
        },
        padding: EdgeInsets.zero,
        child: Icon(icon, color: color, size: 28),
      ),
      Container(
        margin: const EdgeInsets.only(top: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ),
    ],
  );
}

Container _buildTextSection(String section) {
  return Container(
    padding: const EdgeInsets.all(32),
    child: Text(
      section,
      softWrap: true,
      textAlign: TextAlign.justify,
      style: const TextStyle(height: 1.5, fontSize: 15),
    ),
  );
}

class Counter extends StatefulWidget {
  const Counter({Key? key}) : super(key: key);

  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int _counter = 0;
  bool _boolStatus = false;
  Color _statusColor = Colors.black;

  void _buttonPressed() {
    setState(() {
      if (_boolStatus) {
        _boolStatus = false;
        _counter--;
        _statusColor = Colors.black;
      } else {
        _boolStatus = true;
        _counter++;
        _statusColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          onPressed: _buttonPressed,
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.star_fill,
            color: _statusColor,
          ),
        ),
        Text('$_counter'),
      ],
    );
  }
}

/* ***********************************************************************
 *                           HelloWidget
 * **********************************************************************/

class HelloWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Hello Page'),
      ),
      child: SafeArea(
        child: Center(
          child: CupertinoButton(
            onPressed: () {
              showCupertinoAlertDialog(context);
            },
            child: const Text(
              'Hello, Press Here!',
              style: TextStyle(fontSize: 28, color: CupertinoColors.black),
            ),
          ),
        ),
      ),
    );
  }
}

void showCupertinoAlertDialog(BuildContext context) async {
  final result = await showCupertinoDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return CupertinoAlertDialog(
        title: const Text('AlertDialog Sample'),
        content: const Text("Select button you want"),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context, "OK");
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(context, "Cancel");
            },
          ),
        ],
      );
    },
  );

  debugPrint("showCupertinoAlertDialog(): $result");
}

class SearchWidget extends StatefulWidget {
  const SearchWidget({Key? key}) : super(key: key);

  @override
  State<SearchWidget> createState() => _SearchHomePageState();
}

class _SearchHomePageState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchVideosFromServer();
  }

  // 서버에서 데이터 가져오기
  Future<void> _fetchVideosFromServer() async {
    const url = 'http://localhost:3000/get_all';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // JSON 디코딩 (객체 리스트로 디코딩)
        final List<dynamic> items = json.decode(response.body);

        setState(() {
          // 데이터를 List<Map<String, dynamic>>로 변환하여 저장
          _allVideos = items.cast<Map<String, dynamic>>();
          _filteredVideos = List.from(_allVideos); // 초기에는 전체 데이터를 필터에 넣음
        });
      } else {
        print('Failed to load items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching items: $e');
    }
  }
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      // 검색창이 비어 있으면 전체 데이터를 보여줌
      setState(() {
        _filteredVideos = List.from(_allVideos);
      });
      return;
    }

    // 검색창 입력이 있으면 디바운싱 후 서버 요청
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSearchResults(query);
    });
  }


  // 서버 요청 로직
  Future<void> _fetchSearchResults(String query) async {
    final url = Uri.parse('http://localhost:3000/search');

  try {
    final response = await http.get(url.replace(queryParameters: {'query': query}));

    if (response.statusCode == 200) {
      // JSON 응답 처리
      final List<dynamic> results = json.decode(response.body);

      setState(() {
        _filteredVideos = results.cast<Map<String, dynamic>>(); // 결과를 리스트로 변환
      });
    } else {
      print('Failed to load search results: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching search results: $e');
  }
  }

  void _showUploadDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('Upload Options'),
          message: const Text('업로드 방식을 선택해주세요.'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              child: const Text('Youtube URL으로 업로드'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToYoutubeUploadPage(context, const YoutubeUploadPage());
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('직접 mp4 파일 업로드'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToDirectUploadPage(context, const DirectUploadPage());
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  /// 새로운 페이지로 이동하는 함수
  void _navigateToYoutubeUploadPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => page),
    );
  }

  /// 새로운 페이지로 이동하는 함수
  void _navigateToDirectUploadPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => page),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Search'),
        trailing: GestureDetector(
          onTap: () {
            _showUploadDialog(context);
          },
          child: Icon(
            CupertinoIcons.cloud_upload,
            size: 24,
            color: CupertinoColors.activeGreen,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 검색 창
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                prefixIcon: const Icon(CupertinoIcons.search),
                placeholder: "Search videos...",
                onChanged: _onSearchChanged,
              ),
            ),

            // 검색 결과 리스트
            Expanded(
              child: ListView.builder(
                itemCount: _filteredVideos.length,
                itemBuilder: (context, index) {
                  return CupertinoListTile(_filteredVideos[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YoutubeUploadPage extends StatelessWidget {
  const YoutubeUploadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Youtube Upload'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).pop(); // 이전 페이지로 돌아가기
          },
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: Center(
        child: const Text('Youtube Upload Page'),
      ),
    );
  }
}

class DirectUploadPage extends StatelessWidget {
  const DirectUploadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Direct Upload'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).pop(); // 이전 페이지로 돌아가기
          },
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: Center(
        child: const Text('Direct Upload Page'),
      ),
    );
  }
}


/// 검색 결과 항목을 표시하기 위한 간단한 Cupertino 스타일의 ListTile
class CupertinoListTile extends StatelessWidget {
  final Map<String, dynamic> videoData;

  const CupertinoListTile(this.videoData, {Key? key}) : super(key: key);

  /// 날짜 포맷을 변경하는 함수
  String _formatDate(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) {
      return 'Unknown'; // Null 또는 빈 값 처리
    }
    try {
      final date = DateTime.parse(dateTime); // 문자열을 DateTime 객체로 변환
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'; // 원하는 형식으로 변환
    } catch (e) {
      return 'Invalid Date'; // 변환 실패 시 처리
    }
  }


  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      onPressed: () {
        // 항목 클릭 시 동작
        showCupertinoDialog(
          context: context,
          builder: (BuildContext ctx) {
            return CupertinoAlertDialog(
              title: Text(videoData['title'] ?? 'No Title'),
              content: Text(videoData['description'] ?? 'No Description'),
              actions: <CupertinoDialogAction>[
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            videoData['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            videoData['description'] ?? 'No Description',
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Meta information: created_at, views, likes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDate(videoData['created_at']) ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
              Row(
                children: [
                  // Views
                  const Icon(CupertinoIcons.eye, size: 16, color: CupertinoColors.systemGrey2),
                  const SizedBox(width: 4),
                  Text(
                    '${videoData['views'] ?? 0} views',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Likes
                  const Icon(CupertinoIcons.heart_fill, size: 16, color: CupertinoColors.systemRed),
                  const SizedBox(width: 4),
                  Text(
                    '${videoData['likes'] ?? 0} likes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: CupertinoColors.separator, thickness: 1, height: 16),
        ],
      ),
    );


  }
}
