import 'dart:io';
import 'dart:typed_data';

// Simple SQLite binary manipulation - we'll use the app itself instead
// Let's create a helper that uses adb to run content provider or similar

void main() async {
  // Since we can't easily modify SQLite binary, let's use a workaround:
  // Create a Dart script that the Flutter app can execute via test driver
  // Or better - use Node.js / PowerShell with sqlite

  // Try PowerShell approach
  final result = await Process.run('powershell', [
    '-Command',
    '''
    # Download sqlite3 if not present
    \$sqlitePath = "C:\\Users\\Administrator\\sqlite3.exe"
    if (-not (Test-Path \$sqlitePath)) {
      Write-Host "Downloading sqlite3..."
      Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-tools-win-x64-3470200.zip" -OutFile "C:\\Users\\Administrator\\sqlite3.zip"
      Expand-Archive -Path "C:\\Users\\Administrator\\sqlite3.zip" -DestinationPath "C:\\Users\\Administrator\\sqlite3_temp" -Force
      Copy-Item "C:\\Users\\Administrator\\sqlite3_temp\\sqlite-tools-win-x64-3470200\\sqlite3.exe" \$sqlitePath
      Remove-Item "C:\\Users\\Administrator\\sqlite3.zip" -Force
      Remove-Item "C:\\Users\\Administrator\\sqlite3_temp" -Recurse -Force
    }
    Write-Host "sqlite3 ready"
    '''
  ]);
  print(result.stdout);
  print(result.stderr);

  // Now use sqlite3 to insert data
  final dbPath = r'C:\Users\Administrator\memo_copypaste\temp_db.db';
  final now = '2026-03-07T12:40:00.000';

  final sqls = [
    "INSERT OR REPLACE INTO snippets VALUES('s1','고객 인사 템플릿','안녕하세요 {{고객이름}}님, {{회사명}}입니다.\n오늘 {{날짜}} 연락드립니다.\n감사합니다.','default_general','비즈니스,인사',0,NULL,1,0,15,'고객이름,회사명','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s2','우리은행 계좌','우리은행 1005-XXX-XXXXXX 홍길동','default_account','',1,NULL,0,0,42,'','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s3','집 주소','서울특별시 강남구 테헤란로 123, 4층 402호','default_address','',2,NULL,0,0,8,'','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s4','미팅 요청 이메일','{{담당자}}님께,\n\n안녕하세요, {{회사명}}의 {{이름}}입니다.\n{{날짜}} {{시간}} 미팅을 요청드립니다.\n\n감사합니다.\n{{이름}} 드림','default_email','미팅,업무',3,NULL,1,1,23,'담당자,회사명,이름','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s5','카카오뱅크 계좌','카카오뱅크 3333-XX-XXXXXXX 김철수','default_account','',1,NULL,0,1,31,'','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s6','회사 주소','서울특별시 서초구 반포대로 58, 8층','default_address','회사',2,NULL,0,1,5,'','$now','$now');",
    "INSERT OR REPLACE INTO snippets VALUES('s7','자기소개','안녕하세요, 저는 홍길동입니다.\n메모복붙 앱 개발자로 일하고 있습니다.\n궁금한 점이 있으시면 언제든 연락 주세요!','default_general','소개',0,NULL,0,1,12,'','$now','$now');",
    "INSERT OR REPLACE INTO clipboard_history VALUES('ch1','안녕하세요 김철수님, ABC회사입니다.\n오늘 2026-03-07 연락드립니다.\n감사합니다.',NULL,'$now');",
    "INSERT OR REPLACE INTO clipboard_history VALUES('ch2','우리은행 1005-XXX-XXXXXX 홍길동',NULL,'$now');",
    "INSERT OR REPLACE INTO clipboard_history VALUES('ch3','서울특별시 강남구 테헤란로 123, 4층 402호',NULL,'$now');",
  ];

  final sqliteExe = r'C:\Users\Administrator\sqlite3.exe';
  if (!File(sqliteExe).existsSync()) {
    print('sqlite3 not found, waiting...');
    await Future.delayed(Duration(seconds: 3));
  }

  for (final sql in sqls) {
    final r = await Process.run(sqliteExe, [dbPath, sql]);
    if (r.stderr.toString().isNotEmpty) print('Error: ${r.stderr}');
  }
  print('All samples inserted!');
}
