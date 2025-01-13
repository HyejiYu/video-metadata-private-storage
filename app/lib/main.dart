import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:intl/intl.dart'; 
import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final _title = 'Private-Video-Metadata-Storage';

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
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
    SearchPage(),
    AdvancedSearchPage(),
    MonitoringPage(),
  ];


  @override
  Widget build(BuildContext context) {
    // Cupertino 스타일의 탭 구조
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search_circle_fill),
            label: 'Integrated Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text_search),
            label: 'Detail Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.device_desktop),
            label: 'Monitoring',
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


class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
        // jsonify({'message': 'No results found'}), 404
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

          // score 기준으로 내림차순 정렬
          _filteredVideos.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
        });

        
      } else {
        setState(() {
          _filteredVideos = [];
        });
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
                _navigateToYoutubeUploadPage(context, const YoutubeUploadPage(options: ['news', 'aws', 'infra', 'project', 'dart', 'flutter', 'fullstack', 'elasticsearch','game']));
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('직접 mp4 파일 업로드'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToDirectUploadPage(context, const DirectUploadPage(options: ['news', 'aws', 'infra', 'project', 'dart', 'flutter', 'fullstack', 'elasticsearch', 'game']));
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

  /// youtube Url 업로드 페이지로 전환
  void _navigateToYoutubeUploadPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => page),
    );
  }

  /// 직접 업로드 페이지로 전환
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
        leading: GestureDetector(
          onTap: () async {
            await _fetchSearchResults(_searchController.text);
            setState(() {});
          },
          child: Icon(
            CupertinoIcons.refresh,
            size: 24,
            color: CupertinoColors.activeGreen,
          )
        ),
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
                placeholder: "검색어를 입력해주세요...",
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

// 서버 요청 로직
Future<Response?> uploadVideo({
  required final title,
  required final description,
  required final owner,
  required final password,
  required bool is_open,
  required String category,
  required bool is_youtube,
  required String video_url,
  required List<String> keywords,
  String filePath = '',
}) async {
  late String url;
  late FormData formData;

  // JSON 데이터 생성
  final Map<String, dynamic> data = {
    "title": title,
    "description": description,
    "category": category,
    "owner": owner,
    "password": password,
    "is_open": is_open,
    "is_youtube": is_youtube,
    "video_url": video_url,
    "keywords": keywords,
  };

  if (is_youtube == true) {
    url = Uri.parse('http://localhost:3000/upload/youtube').toString();
    formData = FormData.fromMap({
      'data': jsonEncode(data),
    });
  } else {
    url = Uri.parse('http://localhost:3000/upload/file').toString();
    formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath),
      'data': jsonEncode(data),
    });
  }

  try {
    // Dio 요청
    final dio = Dio();
    final response = await dio.post(
      url,
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    // 성공/실패 상태 출력
    if (response.statusCode == 200) {
      print('File uploaded successfully: ${response.data}');
    } else {
      print('Failed to upload file. Status code: ${response.statusCode}');
      print('Response data: ${response.data}');
    }

    // response 반환
    return response;

  } catch (e) {
    if (e is DioException) {
      print('DioException occurred!');
      if (e.response != null) {
        print('Error response: ${e.response?.data}');
      } else {
        print('No response received.');
      }
    } else {
      print('Unexpected error: $e');
    }

    // 예외 발생 시 null 반환
    return null;
  }
}

class YoutubeUploadPage extends StatefulWidget {
  final List<String> options;

  const YoutubeUploadPage({Key? key, required this.options}) : super(key: key);

  @override
  State<YoutubeUploadPage> createState() => _YoutubeUploadPageState();
}


class _YoutubeUploadPageState extends State<YoutubeUploadPage> {
  // 입력받을 데이터 변수
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  final List<String> _selectedKeywords = [];
  
  // 로딩 상태 관리
  bool isLoading = false;
  // 공개 여부 (Toggle)
  bool _isPublic = true;

  // 선택 가능한 카테고리
  final List<String> _categories = [
    'FullStack',
    'BackEnd',
    'FrontEnd',
    'Data Analysis',
    'AI',
    'Machine Learning',
    'Data Engineering',
    'Infra',
    'Algorithm',
    'Game',
    'Etcetera'
  ];
  String _selectedCategory = 'FullStack';

  void _onOptionToggle(String option, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedKeywords.add(option); // 선택된 항목 추가
      } else {
        _selectedKeywords.remove(option); // 선택 해제된 항목 제거
      }
    });
  }

  void _showCategoryPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: _categories.indexOf(_selectedCategory),
            ),
            itemExtent: 32,
            onSelectedItemChanged: (int index) {
              setState(() {
                _selectedCategory = _categories[index];
              });
            },
            children: _categories.map((String category) {
              return Center(child: Text(category));
            }).toList(),
          ),
        );
      },
    );
  }
    
  // ScrollController 추가
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    // 컨트롤러 해제
    _titleController.dispose();
    _descriptionController.dispose();
    _ownerController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

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
      child: SafeArea(
        child: CupertinoScrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 입력
                const Text('Title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _titleController,
                  placeholder: 'Enter title',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 설명 입력
                const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: 'Enter description',
                  padding: const EdgeInsets.all(12),
                  maxLines: 5,
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 소유자 입력
                const Text('Owner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _ownerController,
                  placeholder: 'Enter owner name',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 비밀번호 입력
                const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Enter password',
                  obscureText: true,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 공개 여부 (Toggle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Public', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    CupertinoSwitch(
                      value: _isPublic,
                      onChanged: (bool value) {
                        setState(() {
                          _isPublic = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 카테고리 선택
                const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoButton(
                  child: Text(
                    _selectedCategory,
                    style: const TextStyle(fontSize: 16, color: CupertinoColors.activeGreen),
                  ),
                  onPressed: () => _showCategoryPicker(context),
                ),
                const SizedBox(height: 16),

                // Keywords 다중 선택
                const Text('Keywords', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 200, // 고정된 높이를 지정하여 렌더링 문제 방지
                  child: ListView.builder(
                    itemCount: widget.options.length,
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      final isSelected = _selectedKeywords.contains(option);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                            CupertinoSwitch(
                              value: isSelected,
                              onChanged: (bool value) {
                                _onOptionToggle(option, value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // youtube url
                const Text('Youtube URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _youtubeUrlController,
                  placeholder: 'Enter youtube url...',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 제출 버튼
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        color: CupertinoColors.systemGreen,
                        onPressed: isLoading ? null : () async {
                          setState(() {
                            isLoading = true; // 로딩 시작
                          });

                          try {
                            // 서버 업로드 요청
                            final response = await uploadVideo(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              owner: _ownerController.text,
                              password: _passwordController.text,
                              is_open: _isPublic,
                              category: _selectedCategory,
                              is_youtube: true,
                              video_url: _youtubeUrlController.text,
                              keywords: _selectedKeywords,
                            );
                            
                            if (response != null && response.statusCode == 200){
                              // 완료 메시지 표시
                              showCupertinoDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('Upload Complete'),
                                    content: const Text('Your video has been successfully uploaded.'),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        child: const Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop(); // AlertDialog 닫기
                                          Navigator.of(context).pop(); // 이전 페이지로 돌아가기
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // 실패 메시지 표시
                              showCupertinoDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('Upload Failed'),
                                    content: Text('Server responded with status code: ${response?.statusCode}'),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        child: const Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop(); // AlertDialog 닫기
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          } catch (e) {
                            // 에러 메시지 표시
                            showCupertinoDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return CupertinoAlertDialog(
                                  title: const Text('Upload Failed'),
                                  content: Text('An error occurred: $e'),
                                  actions: [
                                    CupertinoDialogAction(
                                      isDefaultAction: true,
                                      child: const Text('OK'),
                                      onPressed: () {
                                        Navigator.of(context).pop(); // AlertDialog 닫기
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          } finally {
                            setState(() {
                              isLoading = false; // 로딩 종료
                            });
                          }
                        },
                        child: isLoading
                            ? const CupertinoActivityIndicator() // 로딩 인디케이터 표시
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
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


class DirectUploadPage extends StatefulWidget {
  final List<String> options;

  const DirectUploadPage({Key? key, required this.options}) : super(key: key);

  @override
  State<DirectUploadPage> createState() => _DirectUploadPageState();
}


class _DirectUploadPageState extends State<DirectUploadPage> {
  // 입력받을 데이터 변수
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedFilePath = "";
  final List<String> _selectedKeywords = [];
  // 로딩 상태 관리
  bool isLoading = false;

  // 공개 여부 (Toggle)
  bool _isPublic = true;

  // 선택 가능한 카테고리
  final List<String> _categories = [
    'FullStack',
    'BackEnd',
    'FrontEnd',
    'Data Analysis',
    'AI',
    'Machine Learning',
    'Data Engineering',
    'Infra',
    'Algorithm',
  ];
  String _selectedCategory = 'FullStack';

  void _onOptionToggle(String option, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedKeywords.add(option); // 선택된 항목 추가
      } else {
        _selectedKeywords.remove(option); // 선택 해제된 항목 제거
      }
    });
  }

  void _showCategoryPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: _categories.indexOf(_selectedCategory),
            ),
            itemExtent: 32,
            onSelectedItemChanged: (int index) {
              setState(() {
                _selectedCategory = _categories[index];
              });
            },
            children: _categories.map((String category) {
              return Center(child: Text(category));
            }).toList(),
          ),
        );
      },
    );
  }
    

  // 파일 선택 함수
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['mp4'], // 한 번에 하나의 파일만 선택
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          // 파일 경로를 멤버 변수에 저장
          _selectedFilePath = result.files.single.path!;
        });
        print('Selected file path: $_selectedFilePath');
      } else {
        // 사용자가 파일 선택을 취소한 경우
        print('No file selected');
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }



  
  // ScrollController 추가
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    // 컨트롤러 해제
    _titleController.dispose();
    _descriptionController.dispose();
    _ownerController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      child: SafeArea(
        child: CupertinoScrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 입력
                const Text('Title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _titleController,
                  placeholder: 'Enter title',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 설명 입력
                const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: 'Enter description',
                  padding: const EdgeInsets.all(12),
                  maxLines: 5,
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 소유자 입력
                const Text('Owner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _ownerController,
                  placeholder: 'Enter owner name',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 비밀번호 입력
                const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Enter password',
                  obscureText: true,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),

                // 공개 여부 (Toggle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Public', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    CupertinoSwitch(
                      value: _isPublic,
                      onChanged: (bool value) {
                        setState(() {
                          _isPublic = value;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 카테고리 선택
                const Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                CupertinoButton(
                  child: Text(
                    _selectedCategory,
                    style: const TextStyle(fontSize: 16, color: CupertinoColors.activeGreen),
                  ),
                  onPressed: () => _showCategoryPicker(context),
                ),
                const SizedBox(height: 16),

                // Keywords 다중 선택
                const Text('Keywords', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 200, // 고정된 높이를 지정하여 렌더링 문제 방지
                  child: ListView.builder(
                    itemCount: widget.options.length,
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      final isSelected = _selectedKeywords.contains(option);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                            CupertinoSwitch(
                              value: isSelected,
                              onChanged: (bool value) {
                                _onOptionToggle(option, value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 파일 선택
                CupertinoButton.filled(
                  onPressed: _pickFile,
                  child: const Text("Select a file"),
                ),
                if (_selectedFilePath != null)
                  Text(
                    'Selected file:\n$_selectedFilePath',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  )
                else
                  const Text(
                    'No file selected',
                    style: TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 32),

                // 제출 버튼
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        color: CupertinoColors.systemGreen,
                        onPressed: isLoading ? null : () async {
                          setState(() {
                            isLoading = true; // 로딩 시작
                          });

                          try {
                            // 서버 업로드 요청
                            final response = await uploadVideo(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              owner: _ownerController.text,
                              password: _passwordController.text,
                              is_open: _isPublic,
                              category: _selectedCategory,
                              is_youtube: false,
                              video_url: _titleController.text,
                              keywords: _selectedKeywords,
                            );
                            
                            if (response != null && response.statusCode == 200){
                              // 완료 메시지 표시
                              showCupertinoDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('Upload Complete'),
                                    content: const Text('Your video has been successfully uploaded.'),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        child: const Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop(); // AlertDialog 닫기
                                          Navigator.of(context).pop(); // 이전 페이지로 돌아가기
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // 실패 메시지 표시
                              showCupertinoDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('Upload Failed'),
                                    content: Text('Server responded with status code: ${response?.statusCode}'),
                                    actions: [
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        child: const Text('OK'),
                                        onPressed: () {
                                          Navigator.of(context).pop(); // AlertDialog 닫기
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          } catch (e) {
                            // 에러 메시지 표시
                            showCupertinoDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return CupertinoAlertDialog(
                                  title: const Text('Upload Failed'),
                                  content: Text('An error occurred: $e'),
                                  actions: [
                                    CupertinoDialogAction(
                                      isDefaultAction: true,
                                      child: const Text('OK'),
                                      onPressed: () {
                                        Navigator.of(context).pop(); // AlertDialog 닫기
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          } finally {
                            setState(() {
                              isLoading = false; // 로딩 종료
                            });
                          }
                        },
                        child: isLoading
                            ? const CupertinoActivityIndicator() // 로딩 인디케이터 표시
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
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

Future<Map<String, dynamic>?> getVideoInfoFromServer(String docId) async {
  print("docId: $docId");
  final uri = Uri.http(
    'localhost:3000',
    '/video',
    {'doc_id': docId, 'nocache': DateTime.now().millisecondsSinceEpoch.toString()},
  );
  print("Generated URI: $uri");


  try {
    // print("Request Url: $uri");
    final response = await http.get(uri);
    print("Decoded JSON: ${json.decode(response.body)}");
    if (response.statusCode == 200) {
      // print("Response: ${json.decode(response.body)}");
      return json.decode(response.body);
    } else {
      print("Error: Failed to fetch video info($docId). Status code: ${response.statusCode}");
      return null;
    }
  } catch (e, stackTrace) {
    print("Exception in getVideoInfoFromServer: $e");
    print("StackTrace: $stackTrace");    
    return null;
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
        // 클릭 시 비디오 스트리밍 페이지로 이동
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) {
              // print("videoData['is_youtube']: ${videoData['is_youtube']}");
              if (videoData['is_youtube'] == true) {
                // YouTube 영상일 경우
                return YouTubeVideoPage(docId: videoData['id']);
              } else {
                // 일반 영상일 경우
                return VideoDetailPage(docId: videoData['id']);
              }
            },
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일 및 날짜, 메타 정보
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(8), // 썸네일에 둥근 모서리 추가
                child: Image.network(
                  videoData['thumbnail_url'] ?? '', // 썸네일 URL
                  width: 100,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 70,
                      color: CupertinoColors.systemGrey4,
                      child: const Icon(CupertinoIcons.video_camera, color: CupertinoColors.white),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // 날짜 정보
              Text(
                _formatDate(videoData['created_at']),
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12), // 썸네일과 텍스트 간 간격

          // 텍스트 및 메타 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  videoData['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  videoData['description'] ?? 'No Description',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // 조회수 및 좋아요를 오른쪽 정렬
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox.shrink(), // 왼쪽 공간 채우기
                    Row(
                      children: [
                        // 조회수
                        const Icon(CupertinoIcons.eye, size: 16, color: CupertinoColors.systemGrey2),
                        const SizedBox(width: 4),
                        Text(
                          '${videoData['views'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 좋아요
                        const Icon(CupertinoIcons.heart_fill, size: 16, color: CupertinoColors.systemRed),
                        const SizedBox(width: 4),
                        Text(
                          '${videoData['likes'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.systemGrey2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoDetailPage extends StatefulWidget {
  final String docId; // 서버 요청에 사용할 doc_id

  const VideoDetailPage({Key? key, required this.docId}) : super(key: key);

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false; // 에러 여부 플래그
  String? _errorMessage; // 에러 메시지 저장
  Map<String, dynamic>? _videoData; // 서버에서 받아온 비디오 데이터 저장
  bool _isLiked = false;
  int _likes = 0;
  String _docId = "";

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _sendLikesToServer(String doc_id) async {
    try {
        // 서버로 _likes 값을 전송하는 API 호출
        final response = await http.post(
          Uri.parse('http://localhost:3000/likes'), // 서버 API URL
          headers: {
            'Content-Type': 'application/json', // JSON 형식 명시
          },
          body: jsonEncode({
            'doc_id': doc_id, // 비디오 ID
          }),
        );

        if (response.statusCode == 200) {
          print('Likes successfully sent to the server.');
        } else {
          print('Failed to send likes to the server: ${response.statusCode}');
        }
    } catch (e) {
      print('Error sending likes to the server: $e');
    }
  }

  Future<void> _handleBackNavigation(BuildContext context) async {
    // print("_isLiked: $_isLiked");
    if (_isLiked) {
      print('Sending likes to the server for docId: ${_docId}');
      await _sendLikesToServer(_docId); // 좋아요 상태일 때 서버에 전송
    }
    Navigator.of(context).pop(); // 이전 화면으로 이동
  }

  Future<void> _initializeVideo() async {
    try {
      // 서버에서 Presigned URL 가져오기
      final response = await getVideoInfoFromServer(widget.docId);

      if (response != null && response['presignedUrl'] != null) {
        setState(() {
          _videoData = response;
          _likes = _videoData?['likes'];
          _docId = _videoData?['id'];
        });

        // Presigned URL로 VideoPlayerController 초기화
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(response['presignedUrl']))
          ..initialize().then((_) {
            setState(() {
              _isInitialized = true; // 초기화 완료
              _isPlaying = true; // 초기화 후 자동 재생
            });
            _videoPlayerController.play();
          }).catchError((error) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Video initialization failed: $error';
            });
          });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = response?['error'] ?? 'Failed to load video data.';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error occurred: $e';
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Error'),
          leading: GestureDetector(
            onTap: () async {
              print("Back Button pressed");
              await _handleBackNavigation(context);
            },
            child: const Icon(
              CupertinoIcons.back,
              color: CupertinoColors.activeGreen,
            ),
          ),
        ),
        child: Center(
          child: Text(
            _errorMessage ?? 'Unknown error occurred',
            style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 16),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          "Video",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: GestureDetector(
            onTap: () async {
              print("Back Button pressed");
              await _handleBackNavigation(context);
            },
            child: const Icon(
              CupertinoIcons.back,
              color: CupertinoColors.activeGreen,
            ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // 초기화 중 로딩 인디케이터 표시
            if (!_isInitialized)
              const Center(
                child: CupertinoActivityIndicator(),
              ),

            // 비디오 화면
            if (_isInitialized)
              AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: Stack(
                  children: [
                    // 비디오 플레이어
                    VideoPlayer(_videoPlayerController),

                    // 재생 버튼
                    if (!_isPlaying)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isPlaying = true;
                              _videoPlayerController.play();
                            });
                          },
                          child: const Icon(
                            CupertinoIcons.play_circle_fill,
                            size: 64,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),

                    // 화면 클릭으로 재생/일시정지
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_videoPlayerController.value.isPlaying) {
                            _videoPlayerController.pause();
                            _isPlaying = false;
                          } else {
                            _videoPlayerController.play();
                            _isPlaying = true;
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),

            // DraggableScrollableSheet
            DraggableScrollableSheet(
              initialChildSize: 0.6, // 초기 높이 비율
              minChildSize: 0.2, // 최소 높이 비율
              maxChildSize: 1.0, // 최대 높이 비율
              builder: (BuildContext context, ScrollController scrollController) {
                final List<dynamic> scripts = _videoData?['scripts'] ?? [];

                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _videoData?['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _videoData?['description'] ?? 'No Description',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Created At: ${_videoData?['created_at'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.eye, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${_videoData?['views'] ?? 0} views'),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLiked = !_isLiked; // 좋아요 상태 토글
                                  _likes += _isLiked ? 1 : -1; // 좋아요 수 증가/감소
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked
                                        ? CupertinoIcons.heart_fill
                                        : CupertinoIcons.heart,
                                    size: 16,
                                    color: _isLiked
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGrey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_likes likes',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16), // 줄로 바꾸자.

                        // 스크립트 리스트
                        const Text(
                          'Script',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true, // 부모의 스크롤러와 충돌 방지
                          physics: const NeverScrollableScrollPhysics(), // 부모 스크롤러 사용
                          itemCount: scripts.length,
                          itemBuilder: (context, index) {
                            final script = scripts[index];
                            final time = script['time'];
                            final text = script['text'];

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  // 시간 버튼
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      final timeParts = time.split(':');
                                      final duration = Duration(
                                        minutes: int.parse(timeParts[0]),
                                        seconds: int.parse(timeParts[1]),
                                      );
                                      _videoPlayerController.seekTo(duration);
                                    },
                                    child: Text(
                                      time,
                                      style: const TextStyle(
                                        color: CupertinoColors.activeBlue,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12), // 시간과 텍스트 간 간격
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: CupertinoColors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // title: Text(text, style: const TextStyle( fontSize: 11 )),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class YouTubeVideoPage extends StatefulWidget {
  final String docId;

  const YouTubeVideoPage({Key? key, required this.docId}) : super(key: key);

  @override
  State<YouTubeVideoPage> createState() => _YouTubeVideoPageState();
}

class _YouTubeVideoPageState extends State<YouTubeVideoPage> {
  late YoutubePlayerController _controller;
  String? _videoUrl;
  bool _isLoading = true;
  Map<String, dynamic>? _videoData;
  bool _isLiked = false;
  int _likes = 0;
  String _docId = "";

  @override
  void initState() {
    super.initState();
    _fetchVideoUrl();
  }

  Future<void> _sendLikesToServer(String doc_id) async {
    try {
        // 서버로 _likes 값을 전송하는 API 호출
        final response = await http.post(
          Uri.parse('http://localhost:3000/likes'), // 서버 API URL
          headers: {
            'Content-Type': 'application/json', // JSON 형식 명시
          },
          body: jsonEncode({
            'doc_id': doc_id, // 비디오 ID
          }),
        );

        if (response.statusCode == 200) {
          print('Likes successfully sent to the server.');
        } else {
          print('Failed to send likes to the server: ${response.statusCode}');
        }
    } catch (e) {
      print('Error sending likes to the server: $e');
    }
  }

  Future<void> _handleBackNavigation(BuildContext context) async {
    // print("_isLiked: $_isLiked");
    if (_isLiked) {
      print('Sending likes to the server for docId: ${_docId}');
      await _sendLikesToServer(_docId); // 좋아요 상태일 때 서버에 전송
    }
    Navigator.of(context).pop(); // 이전 화면으로 이동
  }

  Future<void> _fetchVideoUrl() async {
    try {

      final response = await getVideoInfoFromServer(widget.docId);

      if (response != null) {
        setState(() {
          _videoData = response;
          _likes = _videoData?['likes'];
          _docId = _videoData?['id'];
        });

        if (_videoData?['video_url'] != null) {
          setState(() {
            _videoUrl = _videoData?['video_url'];
            _controller = YoutubePlayerController(
              initialVideoId: YoutubePlayer.convertUrlToId(_videoUrl!)!,
              flags: const YoutubePlayerFlags(
                autoPlay: true,
                mute: false,
                enableCaption: false,
              ),
            );
          });
        } else {
          _showError("Video URL not found.");
        }
      } else {
        _showError("Failed to fetch video URL.");
      }
    } catch (e) {
      _showError("An error occurred: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Video'),
        leading: GestureDetector(
          onTap: () async {
            print("Back Button pressed");
            await _handleBackNavigation(context);
          },
          child: const Icon(
            CupertinoIcons.back,
            color: CupertinoColors.activeGreen,
          ),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Material(
                child: YoutubePlayerBuilder(
                  player: YoutubePlayer(controller: _controller),
                  builder: (context, player) {
                    return Column(
                      children: [
                        // Stack으로 동영상 플레이어와 GestureDetector 포함
                        SizedBox(
                          height: 250, // 동영상 플레이어 높이 설정
                          child: Stack(
                            children: [
                              player,
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause(); // 동영상 일시정지
                                  } else {
                                    _controller.play(); // 동영상 재생
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 드래그 가능한 설명 및 스크립트
                        Expanded(
                          child: DraggableScrollableSheet(
                            initialChildSize: 1.0, // 초기 높이 비율
                            minChildSize: 0.2, // 최소 높이 비율
                            maxChildSize: 1.0, // 최대 높이 비율
                            builder: (BuildContext context, ScrollController scrollController) {
                              final List<dynamic> scripts = _videoData?['scripts'] ?? [];

                              return Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _videoData?['title'] ?? 'No Title',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _videoData?['description'] ?? 'No Description',
                                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Created At: ${_videoData?['created_at'] ?? 'Unknown'}',
                                        style: const TextStyle(fontSize: 14, color: Colors.black38),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(CupertinoIcons.eye, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('${_videoData?['views'] ?? 0} views'),
                                          const SizedBox(width: 16),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _isLiked = !_isLiked; // 좋아요 상태 토글
                                                _likes += _isLiked ? 1 : -1; // 좋아요 수 증가/감소
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _isLiked
                                                      ? CupertinoIcons.heart_fill
                                                      : CupertinoIcons.heart,
                                                  size: 16,
                                                  color: _isLiked
                                                      ? CupertinoColors.systemRed
                                                      : CupertinoColors.systemGrey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$_likes likes',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: CupertinoColors.systemGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16), // 줄로 바꾸자.

                                      // 스크립트 리스트
                                      const Text(
                                        'Script',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      ListView.builder(
                                        shrinkWrap: true, // 부모의 스크롤러와 충돌 방지
                                        physics: const NeverScrollableScrollPhysics(), // 부모 스크롤러 사용
                                        itemCount: scripts.length,
                                        itemBuilder: (context, index) {
                                          final script = scripts[index];
                                          final time = script['time'];
                                          final text = script['text'];

                                          return ListTile(
                                            dense: true,
                                            leading: TextButton(
                                              onPressed: () {
                                                final timeParts = time.split(':');
                                                final duration = Duration(
                                                  minutes: int.parse(timeParts[0]),
                                                  seconds: int.parse(timeParts[1]),
                                                );
                                                _controller.seekTo(duration);
                                              },
                                              child: Text(
                                                time,
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 11
                                                ),
                                              ),
                                            ),
                                            title: Text(text, style: const TextStyle( fontSize: 11 )),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class AdvancedSearchPage extends StatefulWidget {
  @override
  _AdvancedSearchPageState createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  // 초기 상태
  String selectedCategory = "FullStack";
  List<String> categories = ['FullStack', 'BackEnd', 'FrontEnd', 'Data Analysis', 'AI', 'Machine Learning', 'Data Engineering', 'Infra', 'Algorithm', 'Game', 'Etcetera'];
  List<String> keywords = ['news', 'aws', 'infra', 'project', 'Dart', 'Flutter', '풀스택', '프로그래밍', 'elasticsearch','game'];
  Set<String> selectedKeywords = {}; // 선택된 키워드
  DateTime startDate = DateTime(2024, 1, 1); // 시작 날짜 기본값
  DateTime endDate = DateTime.now(); // 종료 날짜 기본값
  int? minLikes; // 좋아요 수
  int? minViews; // 조회수
  List<dynamic> _filteredVideos = []; // 검색 결과 리스트

  // 날짜 포맷
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }


  Future<void> _searchAndDisplayResults() async {
    try {
      // 서버에 검색 요청
      final response = await _searchDetail(
        category: selectedCategory,
        keywords: selectedKeywords,
        created_at_start: startDate,
        created_at_end: endDate,
        min_likes: minLikes,
        min_views: minViews,
      );

      if (response != null && response.statusCode == 200) {
        // JSON 응답 파싱
        final List<dynamic> results = jsonDecode(response.body);
        print("@@@SearchDetail@@@ result: $results");
        setState(() {
          _filteredVideos = results; // 검색 결과 저장
        });
      } else {
        // 실패 메시지 표시
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text('Search Failed'),
              content: Text('Server responded with status code: ${response?.statusCode}'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // AlertDialog 닫기
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // 에러 메시지 표시
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Search Failed'),
            content: Text('An error occurred: $e'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(); // AlertDialog 닫기
                },
              ),
            ],
          );
        },
      );
    }
  }

  // 서버에 요청
  Future<http.Response?> _searchDetail({
    required String category,
    required Set<String> keywords,
    required DateTime created_at_start,
    required DateTime created_at_end,
    required int? min_likes,
    required int? min_views,
  }) async {
    try {
      print("formatted created_at_start: ${_formatDate(created_at_start)}\nformatted created_at_end: ${_formatDate(created_at_end)}");

      // 쿼리 파라미터 생성
      final Map<String, String> queryParams = {
        'category': category,
        'keywords': keywords.join(','), // 키워드 리스트를 쉼표로 연결
        'created_at': '${_formatDate(created_at_start)},${_formatDate(created_at_end)}',
        if (min_likes != null) 'likes': min_likes.toString(),
        if (min_views != null) 'views': min_views.toString(),
      };

      // URL에 쿼리 파라미터 추가
      final uri = Uri.http(
        'localhost:3000',
        '/search/detail',
        queryParams,
      );

      print('Request URI: $uri'); // 디버깅용 로그

      // GET 요청
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      // 응답 반환
      return response;
    } catch (e) {
      print('Error in _searchDetail: $e');
      return null;
    }
  }

  // 날짜 선택 다이얼로그
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemGrey6,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: isStartDate ? startDate : endDate,
                  minimumDate: DateTime(2000),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      if (isStartDate) {
                        startDate = newDate;
                      } else {
                        endDate = newDate;
                      }
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text("Done"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Advanced Search"),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카테고리 선택
              const Text("Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: 300,
                        color: CupertinoColors.systemGrey6,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: CupertinoPicker(
                                itemExtent: 32,
                                onSelectedItemChanged: (int index) {
                                  setState(() {
                                    selectedCategory = categories[index];
                                  });
                                },
                                children: categories.map((category) {
                                  return Center(
                                    child: Text(
                                      category,
                                      style: const TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis, // 텍스트 잘림 방지
                                      softWrap: false, // 줄바꿈 방지
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            CupertinoButton(
                              child: const Text("Done"),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedCategory, style: const TextStyle(fontSize: 16)),
                    const Icon(CupertinoIcons.chevron_down),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 키워드 선택
              const Text("Keywords", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: keywords.map((keyword) {
                  final isSelected = selectedKeywords.contains(keyword);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedKeywords.remove(keyword);
                        } else {
                          selectedKeywords.add(keyword);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? CupertinoColors.activeGreen : CupertinoColors.systemGrey4,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        keyword,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 게시 날짜 선택
              const Text("게시 날짜", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _selectDate(context, true),
                    child: Text(
                      "시작: ${_formatDate(startDate)}",
                      style: const TextStyle(fontSize: 16, color: CupertinoColors.activeBlue),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _selectDate(context, false),
                    child: Text(
                      "종료: ${_formatDate(endDate)}",
                      style: const TextStyle(fontSize: 16, color: CupertinoColors.activeBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 좋아요 수
              const Text("좋아요 수 (이상)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CupertinoTextField(
                keyboardType: TextInputType.number,
                placeholder: "검색하고 싶은 최소 좋아요 수를 입력해주세요.",
                onChanged: (value) {
                  setState(() {
                    minLikes = int.tryParse(value);
                  });
                },
              ),
              const SizedBox(height: 16),

              // 조회수
              const Text("조회수 (이상)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CupertinoTextField(
                keyboardType: TextInputType.number,
                placeholder: "검색하고 싶은 최소 조회수를 입력해주세요.",
                onChanged: (value) {
                  setState(() {
                    minViews = int.tryParse(value);
                  });
                },
              ),
              const SizedBox(height: 32),

              // 검색 버튼
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoButton.filled(
                      onPressed: _searchAndDisplayResults,
                      child: const Text('Search')
                    ),
                  ),
                ),
              ),

              // 검색 결과 리스트
              Expanded(
                child: _filteredVideos.isEmpty
                    ? const Center(
                        child: Text(
                          'No results found.',
                          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredVideos.length,
                        itemBuilder: (context, index) {
                          return CupertinoListTile(_filteredVideos[index]);
                        },
                    ),
              ),
                    
                  
                  
                
              
            ],
          ),
        ),
      ),
    );
  }
}


// 직접 업로드 영상 중 조회수 순위 반환
Future<Map<String, dynamic>> GetCategoryRatio() async {
  // Flask API URL
  const baseUrl = 'http://localhost:3000';
  const endpoint = '/monitor/category_ratio';

  final url = Uri.parse('$baseUrl$endpoint');

  try {
    // 요청 보내기
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
    });

    // 상태 코드 확인
    if (response.statusCode == 200) {
      // JSON 파싱 후 반환
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // 실패 시 에러 메시지 포함 반환
      return {
        'error': 'Failed to fetch data',
        'statusCode': response.statusCode,
        'message': response.reasonPhrase,
      };
    }
  } catch (e) {
    // 예외 처리
    return {'error': 'An exception occurred', 'details': e.toString()};
  }
}

Future<Map<String, dynamic>> GetViewRank() async {
  final url = Uri.parse('http://localhost:3000/monitor/view_rank'); // Flask API URL

  try {
    // GET 요청 보내기
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // 응답 성공
      final data = jsonDecode(response.body);
      final youtubeVideos = data['youtube_videos'];
      final nonYoutubeVideos = data['non_youtube_videos'];

      print('YouTube Videos:');
      for (var video in youtubeVideos) {
        print('Title: ${video['title']}, Views: ${video['views']}');
      }

      print('\nNon-YouTube Videos:');
      for (var video in nonYoutubeVideos) {
        print('Title: ${video['title']}, Views: ${video['views']}');
      }
      return data;
    } else {
      // 응답 실패
      print('Failed to fetch data. Status Code: ${response.statusCode}');
      return {};
    }
  } catch (e) {
    print('Error: $e');
    return {};
  }
}


class MonitoringPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Monitoring'),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: GetCategoryRatio(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 로딩 상태
            return const Center(
              child: CupertinoActivityIndicator(),
            );
          } else if (snapshot.hasError) {
            // 에러 상태
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (snapshot.hasData) {
            // 데이터 성공적으로 로드
            final data = snapshot.data!;
            final totalDocs = data['total_docs'];
            final results = data['results']; // 각 카테고리와 비율 데이터

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 차트 영역
                      Container(
                        height: 400, 
                        child: _buildPieChartPage(results),
                      ),
                      Divider(color: CupertinoColors.systemGrey.withOpacity(0.3)),
                      const SizedBox(height: 10),
                      // 테이블 영역
                      SizedBox(
                        height: 300, // 테이블 높이를 명시적으로 지정
                        child: _buildTablePage(results),
                      ),
                      Divider(color: CupertinoColors.systemGrey.withOpacity(0.3)),
                      const SizedBox(height: 10),
                      // 유튜브 동영상 view rank
                      FutureBuilder<Map<String, dynamic>>(
                        future: GetViewRank(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CupertinoActivityIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          } else if (snapshot.hasData) {
                            final videoData = snapshot.data!;
                            final youtubeVideos = videoData['youtube_videos'] ?? [];
                            final nonYoutubeVideos = videoData['non_youtube_videos'] ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 유튜브 테이블
                                _buildTableView(context, "Top 10 YouTube Videos", youtubeVideos),
                                const SizedBox(height: 16),
                                // 논유튜브 테이블
                                _buildTableView(context, "Top 10 Non-YouTube Videos", nonYoutubeVideos),
                              ],
                            );
                          } else {
                            return const Center(
                              child: Text('No data available'),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return const Center(
              child: Text('No data available'),
            );
          }
        },
      ),
    );
  }

  Widget _buildPieChartPage(List<dynamic> results) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            '카테고리별 비율',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            width: 300,
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(results),
                  centerSpaceRadius: 40,
                  sectionsSpace: 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablePage(List<dynamic> results) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            '카테고리별 비디오 개수',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CupertinoScrollbar(
              child: CupertinoCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      _buildTableRow("rank", "title", "count", isHeader: true),
                      const Divider(),
                      for (int i = 0; i < results.length; i++)
                        _buildTableRow(
                          (i + 1).toString(),
                          results[i]['keyword'],
                          results[i]['count'].toString(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<dynamic> results) {
    return results.map((result) {
      final keyword = result['keyword'];
      final ratio = result['ratio'];
      return PieChartSectionData(
        value: ratio,
        title: '$keyword\n${ratio.toStringAsFixed(1)}%',
        color: _getColorForCategory(keyword),
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          // fontWeight: FontWeight.bold,
          color: CupertinoColors.black,
        ),
        titlePositionPercentageOffset: 1.4,
      );
    }).toList();
  }

  Color _getColorForCategory(String keyword) {
    switch (keyword) {
      case 'FullStack':
        return Colors.lightGreen;
      case 'news':
        return Colors.lightGreenAccent;
      case 'Data Engineering':
        return Colors.lime;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  Widget _buildTableRow(String id, String name, String value, {bool isHeader = false}) {
    final style = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: isHeader ? 16 : 14,
      color: isHeader ? CupertinoColors.black : CupertinoColors.systemGrey,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(id, style: style),
          Text(name, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildTableRowView(
    BuildContext context,
    String rank,
    String title,
    String views, {
    bool isHeader = false,
    Map<String, dynamic>? videoData, // videoData 전달
  }) {
    final style = TextStyle(
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontSize: isHeader ? 16 : 14,
      color: isHeader ? CupertinoColors.black : CupertinoColors.systemGrey,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 순위
          Text(rank, style: style),
          // 제목 (클릭 가능)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onTap: videoData != null
                    ? () => NavigateToDetailPage(context, videoData)
                    : null,
                child: Text(
                  title,
                  style: style.copyWith(
                    color: CupertinoColors.activeGreen, // 클릭 가능 텍스트 색상
                    decoration: TextDecoration.underline, // 클릭 가능 시 강조
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          // 조회수
          Text(views, style: style),
        ],
      ),
    );
  }

  Widget _buildTableView(BuildContext context, String title, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoScrollbar(
            child: SizedBox(
              height: 300, // 테이블 높이 제한
              child: CupertinoCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTableRowView(
                        context,
                        "Rank",
                        "Title",
                        "Views",
                        isHeader: true,
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final videoData = items[index];
                            return Column(
                              children: [
                                _buildTableRowView(
                                  context,
                                  (index + 1).toString(),
                                  videoData['title'] ?? 'N/A',
                                  videoData['views']?.toString() ?? '0',
                                  videoData: videoData, // videoData 전달
                                ),
                                const Divider(),
                              ],
                            );
                          },
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
    );
  }

}

// Helper 메서드로 페이지 이동 로직 분리
void NavigateToDetailPage(BuildContext context, Map<String, dynamic> videoData) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) {
        if (videoData['is_youtube'] == true) {
          return YouTubeVideoPage(docId: videoData['id']);
        } else {
          return VideoDetailPage(docId: videoData['id']);
        }
      },
    ),
  );
}

class CupertinoCard extends StatelessWidget {
  final Widget child;

  const CupertinoCard({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}