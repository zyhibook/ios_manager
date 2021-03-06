import 'dart:async';
import 'dart:developer';
import 'package:aqua/page/home/home.dart';
import 'package:connectivity/connectivity.dart';
import 'package:f_logs/f_logs.dart';
import 'package:flutter/services.dart';
import 'package:aqua/common/widget/double_pop.dart';
import 'package:aqua/constant/constant_var.dart';
import 'package:aqua/model/file_model.dart';
import 'package:aqua/utils/mix_utils.dart';
import 'package:aqua/utils/theme.dart';
import 'constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aqua/external/bot_toast/bot_toast.dart';
import 'external/bot_toast/src/toast_navigator_observer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'external/bot_toast/src/bot_toast_init.dart';
import 'package:aqua/model/common_model.dart';
import 'package:aqua/utils/notification.dart';
import 'package:aqua/model/theme_model.dart';
import 'package:aqua/utils/store.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Aqua extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AquaState();
  }
}

class _AquaState extends State<Aqua> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeModel>(
          create: (_) => ThemeModel(),
        ),
        ChangeNotifierProvider<CommonModel>(
          create: (_) => CommonModel(context),
        ),
        ChangeNotifierProvider<FileModel>(
          create: (_) => FileModel(),
        ),
      ],
      child: AquaWrapper(),
    );
  }
}

class AquaWrapper extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AquaWrapperState();
  }
}

class _AquaWrapperState extends State<AquaWrapper> {
  ThemeModel _themeModel;
  CommonModel _commonModel;
  bool _prepared;
  bool _settingMutex;
  StreamSubscription<ConnectivityResult> _connectSubscription;

  @override
  void initState() {
    super.initState();
    _prepared = false;
    _settingMutex = true;

    LocalNotification.initLocalNotification(onSelected: (String payload) {
      debugPrint(payload);
    });

    _connectSubscription =
        Connectivity().onConnectivityChanged.listen(_setInternalIp);
  }

  Future<void> _setInternalIp(ConnectivityResult result) async {
    try {
      if (_commonModel.enableConnect != null) {
        String internalIp = await Connectivity().getWifiIP() ??
            await MixUtils.getIntenalIp() ??
            LOOPBACK_ADDR;
        await _commonModel.setInternalIp(internalIp);
      }
    } catch (e) {}
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _themeModel = Provider.of<ThemeModel>(context);
    _commonModel = Provider.of<CommonModel>(context);

    if (_settingMutex) {
      _settingMutex = false;
      String theme = (await Store.getString(THEME_KEY)) ?? LIGHT_THEME;
      await _themeModel.setTheme(theme).catchError((err) {
        FLog.error(text: '', methodName: 'setTheme');
      });
      await _commonModel.initCommon().catchError((err) {
        FLog.error(text: '', methodName: 'initCommon');
      });
      await _setInternalIp(null);
      setState(() {
        _prepared = true;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _connectSubscription?.cancel();
    _commonModel.setAppInit(false);
  }

  @override
  Widget build(BuildContext context) {
    log("root render ====== (prepared = $_prepared)");
    AquaTheme themeData = _themeModel.themeData;

    return _prepared
        ? AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              systemNavigationBarIconBrightness:
                  themeData.systemNavigationBarIconBrightness,
              systemNavigationBarColor: themeData.systemNavigationBarColor,
            ),
            child: CupertinoApp(
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                AppLocalizations.delegate
              ],
              supportedLocales: [
                const Locale('zh'),
                const Locale('en'),
              ],
              locale: Locale(_commonModel.language),
              builder: BotToastInit(),
              navigatorObservers: [
                BotToastNavigatorObserver(),
              ],
              title: 'aqua',
              theme: CupertinoThemeData(
                scaffoldBackgroundColor: themeData.scaffoldBackgroundColor,
                textTheme: CupertinoTextThemeData(
                  textStyle: TextStyle(
                    color: themeData.itemFontColor,
                  ),
                ),
              ),
              home: DoublePop(
                commonModel: _commonModel,
                themeModel: _themeModel,
                child: HomePage(),
              ),
            ),
          )
        : Container(color: themeData?.scaffoldBackgroundColor ?? Colors.white);
  }
}
