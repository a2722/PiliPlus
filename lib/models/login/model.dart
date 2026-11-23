class CaptchaDataModel {
  CaptchaDataModel({
    this.type,
    this.token,
    this.geetest,
    this.tencent,
    this.validate,
    this.seccode,
    this.lotNumber,
    this.captchaOutput,
    this.passToken,
    this.genTime,
  });

  String? type;
  String? token;
  GeetestData? geetest;
  Tencent? tencent;

  /// 极验 v3
  String? validate;
  String? seccode;

  /// 极验 v4（B 站 2026-11 起 safecenter 返回 recaptcha_type=geetest4）
  String? lotNumber;
  String? captchaOutput;
  String? passToken;
  String? genTime;

  CaptchaDataModel.fromJson(Map<String, dynamic> json) {
    type = json["type"];
    token = json["token"];
    geetest = json["geetest"] != null
        ? GeetestData.fromJson(json["geetest"])
        : null;
    tencent = json["tencent"] != null
        ? Tencent.fromJson(json["tencent"])
        : null;
  }
}

class GeetestData {
  const GeetestData({
    required this.challenge,
    required this.gt,
  });

  final String challenge;
  final String gt;

  factory GeetestData.fromJson(Map<String, dynamic> json) =>
      GeetestData(challenge: json["challenge"], gt: json["gt"]);
}

class Tencent {
  Tencent({this.appid});
  String? appid;
  Tencent.fromJson(Map<String, dynamic> json) {
    appid = json["appid"];
  }
}
