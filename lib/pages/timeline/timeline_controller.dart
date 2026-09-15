import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/utils/anime_season.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/bangumi_timeline_store.dart';
import 'package:mobx/mobx.dart';

part 'timeline_controller.g.dart';

class TimelineController = _TimelineController with _$TimelineController;

abstract class _TimelineController with Store {
  _TimelineController(this._collectRepository);

  final ICollectRepository _collectRepository;

  @observable
  ObservableList<List<BangumiItem>> bangumiCalendar =
      ObservableList<List<BangumiItem>>();

  /// 接口返回的原始日历，详情页的自定义条目每次都从它重新合并
  List<List<BangumiItem>> _baseBangumiCalendar = [];

  @observable
  String seasonString = '';

  @observable
  bool isLoading = false;

  @observable
  bool isTimeOut = false;

  @observable
  late bool notShowAbandonedBangumis =
      _collectRepository.getTimelineNotShowAbandonedBangumis();

  @observable
  late bool notShowWatchedBangumis =
      _collectRepository.getTimelineNotShowWatchedBangumis();

  @observable
  late bool onlyShowWatchingBangumis =
      _collectRepository.getTimelineOnlyShowWatchingBangumis();

  int _sortType = 3;
  int get sortType => _sortType;

  late DateTime _selectedDate;
  DateTime get selectedDate => _selectedDate;

  bool get _bangumiMirrorEnabled =>
      GStorage.getSetting(SettingsKeys.enableBangumiProxy);

  void init() {
    _selectedDate = DateTime.now();
    seasonString = AnimeSeason(_selectedDate).toString();
    getSchedules();
  }

  // Async actions commit each segment between awaits as one transaction, so
  // clear+addAll never shows observers an intermediate empty list.
  @action
  Future<void> getSchedules() async {
    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    final resBangumiCalendar = await BangumiApi.getCalendar();
    _setBangumiCalendarBase(resBangumiCalendar);
    isLoading = false;
    isTimeOut = bangumiCalendar.isEmpty;
    if (!isTimeOut) {
      _applyCustomTimelineEntries();
      changeSortType(sortType);
    }
  }

  @action
  Future<void> getSchedulesBySeason() async {
    if (_bangumiMirrorEnabled) {
      isLoading = true;
      isTimeOut = false;
      bangumiCalendar.clear();
      final resBangumiCalendar =
          await BangumiApi.getBangumiMirrorSeasonCalendar(
              AnimeSeason(selectedDate).toSeasonStartAndEnd());
      _setBangumiCalendarBase(resBangumiCalendar);
      isLoading = false;
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
      if (!isTimeOut) {
        _applyCustomTimelineEntries();
        changeSortType(sortType);
      }
      return;
    }

    isLoading = true;
    isTimeOut = false;
    bangumiCalendar.clear();
    var time = 0;
    const maxTime = 4;
    const limit = 20;
    var resBangumiCalendar = List.generate(7, (_) => <BangumiItem>[]);
    for (time = 0; time < maxTime; time++) {
      final offset = time * limit;
      var newList = await BangumiApi.getCalendarBySearch(
          AnimeSeason(selectedDate).toSeasonStartAndEnd(), limit, offset);
      for (int i = 0; i < resBangumiCalendar.length; ++i) {
        resBangumiCalendar[i].addAll(newList[i]);
      }
      bangumiCalendar.clear();
      bangumiCalendar.addAll(resBangumiCalendar);
    }
    _setBangumiCalendarBase(resBangumiCalendar);
    isLoading = false;
    if (bangumiCalendar.isEmpty) {
      isTimeOut = true;
    } else {
      isTimeOut = bangumiCalendar.every((innerList) => innerList.isEmpty);
    }
    if (!isTimeOut) {
      _applyCustomTimelineEntries();
      changeSortType(sortType);
    }
  }

  /// 保存接口返回的原始日历，并把展示用日历重置为它的副本
  void _setBangumiCalendarBase(List<List<BangumiItem>> calendar) {
    _baseBangumiCalendar =
        calendar.map((dayList) => List<BangumiItem>.from(dayList)).toList();
    _resetBangumiCalendarFromBase();
  }

  void _resetBangumiCalendarFromBase() {
    bangumiCalendar.clear();
    bangumiCalendar.addAll(
      _baseBangumiCalendar
          .map((dayList) => List<BangumiItem>.from(dayList))
          .toList(),
    );
  }

  /// 把番剧详情页设置的「在时间表展示」条目合并进日历
  void _applyCustomTimelineEntries() {
    if (bangumiCalendar.isEmpty) {
      return;
    }
    final weekdays = BangumiTimelineStore.loadShownWeekdays();
    if (weekdays.isEmpty) {
      return;
    }
    final items = <int, BangumiItem>{};
    for (final collectible in GStorage.collectibles.values) {
      final bangumiItem = collectible.bangumiItem;
      if (!weekdays.containsKey(bangumiItem.id)) {
        continue;
      }
      if (!bangumiKeepsTimelineEntry(collectible.type)) {
        continue;
      }
      items[bangumiItem.id] = bangumiItem;
    }
    if (items.isEmpty) {
      return;
    }
    final merged = mergeBangumiTimelineEntries(
      base: bangumiCalendar,
      weekdays: weekdays,
      items: items,
    );
    bangumiCalendar.clear();
    bangumiCalendar.addAll(merged);
  }

  /// 详情页修改自定义条目后刷新时间表
  void refreshCustomTimelineEntries() {
    if (_baseBangumiCalendar.isEmpty) {
      return;
    }
    _resetBangumiCalendarFromBase();
    _applyCustomTimelineEntries();
    changeSortType(sortType);
  }

  void tryEnterSeason(DateTime date) {
    _selectedDate = date;
    seasonString = "加载中 ٩(◦`꒳´◦)۶";
  }

  /// Sort type: 1 = default (id), 2 = score, 3 = heat (votes).
  @action
  void changeSortType(int type) {
    if (type < 1 || type > 3) {
      return;
    }
    _sortType = type;
    var resBangumiCalendar = bangumiCalendar.toList();
    for (var dayList in resBangumiCalendar) {
      switch (_sortType) {
        case 1:
          dayList.sort((a, b) => a.id.compareTo(b.id));
          break;
        case 2:
          dayList.sort((a, b) => (b.ratingScore).compareTo(a.ratingScore));
          break;
        case 3:
          dayList.sort((a, b) => (b.votes).compareTo(a.votes));
          break;
        default:
      }
    }
    bangumiCalendar.clear();
    bangumiCalendar.addAll(resBangumiCalendar);
  }

  @action
  Future<void> setNotShowAbandonedBangumis(bool value) async {
    notShowAbandonedBangumis = value;
    await _collectRepository.updateTimelineNotShowAbandonedBangumis(value);
  }

  @action
  Future<void> setNotShowWatchedBangumis(bool value) async {
    notShowWatchedBangumis = value;
    await _collectRepository.updateTimelineNotShowWatchedBangumis(value);
  }

  Set<int> loadAbandonedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.abandoned);
  }

  Set<int> loadWatchedBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watched);
  }

  @action
  Future<void> setOnlyShowWatchingBangumis(bool value) async {
    onlyShowWatchingBangumis = value;
    await _collectRepository.updateTimelineOnlyShowWatchingBangumis(value);
  }

  Set<int> loadWatchingBangumiIds() {
    return _collectRepository.getBangumiIdsByType(CollectType.watching);
  }
}
