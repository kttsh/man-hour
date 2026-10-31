package jp.co.nttdatamhis.kosukeijo.common;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class KeijoKosuConstants {

	/** コンストラクタ. */
	private KeijoKosuConstants() {
	}

	public static final class SessionAttribute {

		/** ユーザID */
		public static final String LOGIN_USER_ID = "loginUserId";

		/** ユーザ名称 */
		public static final String LOGIN_USER_NAME = "loginUserName";

		/** 権限(複数の場合はプライオリティの高い権限) */
		public static final String LOGIN_USER_ROLE_ID = "loginUserRoleId";

		/** 権限名称(複数の場合はプライオリティの高い権限) */
		public static final String LOGIN_USER_ROLE_NAME = "loginUserRoleName";

		/** 会社コード */
		public static final String LOGIN_COMPANY_CODE = "loginCompanyCd";

		/** 会社コード(GIM) */
		public static final String LOGIN_GIM_COMPANY_CODE = "loginGimCompanyCd";

		/** 会社名称 */
		public static final String LOGIN_COMPANY_NAME = "loginCompanyName";

		/** 従業員番号 */
		public static final String LOGIN_MHI_EMP_NO = "loginMhiEmpNo";

		/** 所属コード */
		public static final String LOGIN_SHOZOKU_CODE = "loginShozokuCd";

		/** 所属 */
		public static final String LOGIN_SHOZOKU_NAME = "loginShozokuName";

		/** メールアドレス */
		public static final String LOGIN_MAIL_ADDRESS = "loginMailAddress";

		/** 権限 */
		public static final String LOGIN_AUTHORITY = "loginAuthority";

		/** 会社権限リスト */
		public static final String LOGIN_COMPANY_AUTHORITY_LIST = "loginCompanyAuthorityList";

		/**  */
		public static final String EXTERNAL_SYSTEM_INFO = "externalSystemInfo";
		
		/** 一覧編集 上限件数 */
		public static final String AUTO_GROW_COLLECTION_LIMIT = "autoGrowCollectionLimit";

	}

	/** ステータス */
	public static final class Status {
		/** 上長確認待ち */
		public static final String JYOTYO_SHOUNIN_MATI = "1";
		/** 工数確定担当確認待ち */
		public static final String TANTOU_SHOUNIN_MATI = "2";
		/** 修正指示 */
		public static final String SHUUSEI_SIJI = "3";
		/** 確認済 */
		public static final String SHOUNIN_SUMI = "4";
		/** 確定済 */
		public static final String KAKUTEI_SUMI = "5";
		/** 締切済 */
		public static final String SIMEKIRI_SUMI = "6";
		/** 経理接続済(間接融通時間のみ) */
		public static final String KEIRI_SETSUZOKU_SUMI = "7";
	}

	/** 確認区分 */
	public static final class ShouninKbn {
		/** 上長確認 */
		public static final String JYOTYO_SHOUNIN = "1";
		/** 工数確定担当確認 */
		public static final String TANTOU_SHOUNIN = "2";
	}

	/** 処置内容 */
	public static final class ShotiNaiyou {
		/** 上程 */
		public static final String JYOTEI = "1";
		/** 確認 */
		public static final String SHOUNIN = "2";
		/** 修正指示 */
		public static final String SHUUSEI_SIJI = "3";
	}

	/** 確認タイプ */
	public static final class ShouninType {
		/** 上長 */
		public static final String JYOTYO = "1";
		/** 上長と工数管理部門 */
		public static final String KOSU_KANRI = "2";
		/** 修正指示 */
		public static final String SHUUSEI_SIJI = "3";
	}

	/** カスタムチェック */
	public static final class CheckType {
		/** Size */
		public static final String SIZE = "1";
		/** MaxLength */
		public static final String MAXLENGTH = "2";
		/** Range */
		public static final String RANGE = "3";
		/** NotBlank */
		public static final String NOT_BLANK = "4";
		/** 半角英数字 */
		public static final String ALPHA_NUMERIC = "5";
		/** 半角 */
		public static final String HANKAKU = "6";
		/** 半角数値 */
		public static final String NUMERIC = "7";
		/** 年月 */
		public static final String YEARMONTH = "8";
	}

	/** 変更履歴更新区分 */
	public static final class HnkoRirekiShuseiKbn {
		/** 更新前 */
		public static final String BEFORE = "B";
		/** 更新後 */
		public static final String AFTER = "A";
	}

	/** I/Fステータス */
	public static final class IfStatus {
		/** 未接続 */
		public static final String MI_SETUZOKU = "0";
		/** 接続済 */
		public static final String SETUZOKU_SUMI = "1";
	}

	/** 確定ステータス */
	public static final class KakuteiStatus {
		/** 未確定 */
		public static final String MI_KAKUTEI = "0";
		/** 確定済 */
		public static final String KAKUTEI_SUMI = "1";
	}

	/** 締切フラグ */
	public static final class ShimekiriFlg {
		/** 未締切 */
		public static final String MI_SHIMEKIRI = "0";
		/** 締切済 */
		public static final String SHIMEKIRI_SUMI = "1";
	}

	/** SAP連携ステータス */
	public static final class SapRenkeiStatus {
		/** 連携済み */
		public static final String RENKEI_SUMI = "0";
	}

	/** 外部インタフェースID */
	public static final class IntarfaceID {
		/** 活動配分データSAP-IN(登録)I/F */
		public static final String IF01 = "IF01";
		/** 融通データSAP-IN(登録)I/F */
		public static final String IF03 = "IF03";
		/** 工数データ D-MAP接続 */
		public static final String IF05 = "IF05";
	}

	/** IFタイプNo */
	public static final class IfTypeNo {
		/** 活動配分 */
		public static final String KATUDO_HAIBUN = "ICO02";
		/** 原価再転記 */
		public static final String GENKA_SAITENKI = "ICO01";
	}

	/** IFタイプNo */
	public static final class IfKubun {
		/** 通常 */
		public static final String KATUDO_HAIBUN_TUJO = "00001";
		/** 締切済 */
		public static final String KATUDO_HAIBUN_KAGETU = "00002";
		/** 原価再転記 */
		public static final String GENKA_SAITENKI = "00003";
	}
	
	/** 原価再転記 固定値項目 */
	public static final class genkaSaitenkiConst {
		/** 数量単位 */
		public static final String SURYO_TANI = "HR";
	}

	/** 連番MAXCOUNT管理用途 */
	public static final class MaxcountManagerUsage {
		/** 経理接続連番管理 */
		public static final String KEIRI_SETUZOKU = "IF01";
		/** 経理接続融通連番管理 */
		public static final String KEIRI_SETUZOKU_YUZU = "IF03";
	}
	
	/** 伝票ヘッダテキスト連番カウントアップ単位 */
	public static final class IfMeisaiCountUp {
		/** 活動配分 */
		public static final String KATUDO_HAIBUN = "10";
		/** 原価再転記 */
		public static final String GENKA_SAITENKI = "10";
	}

	/** Excelアップロード判定 */
	public static final class ExcelUploadStatus {
		/** エラーなし */
		public static final String OK = "OK";
		/** エラーあり */
		public static final String NG = "NG";
	}

	/** 画面表示用項目名 */
	public static final class DisplayCodeName {
		/** WBS */
		public static final String WBS = "WBS";
		/** OPA */
		public static final String OPA = "OPA";
		/** 原価センタ */
		public static final String GENKA_CENTER = "CCA";
		/** 用役コード */
		public static final String YOUEKI = "用役";
		/** 職種コード */
		public static final String SHOKUSHU = "職種";
	}
	
	/** 人事HUB 日次/月次 区分 */
	public static final class jinjiHubIntervalKbn{
		/** 日次 */
		public static final String DAILY = "1";
		/** 月次 */
		public static final String MONTHLY = "2";
	}	
	
	/** 人事HUB 前日/当日 区分 */
	public static final class jinjiHubDayKbn{
		/** 当日 */
		public static final String TODAY = "0";
		/** 前日 */
		public static final String YESTERDAY = "1";
	}
	
	/** 用役・職種区分 */
	public static final class yoekiShokkushuKbn{
		/** 当日 */
		public static final String SHOKUSHU = "1";
		/** 前日 */
		public static final String YOEKI = "2";
	}
	
	/** ユーザ種別 */
	public static final class userType{
		/** 社員 */
		public static final String USER1 = "1";
		/** 労派 */
		public static final String USER3 = "3";
		/** 請負 */
		public static final String USER4 = "4";
		/** その他 */
		public static final String USER9 = "9";
		/** 退職者 */
		public static final String USERNULL = "null";
	}
	
	/** 賃金計上先区分 */
	public static final class appropriationKbn{
		/** 計上_用役 */
		public static final String kbn1 = "計上_用役";
		/** 計上_人工 */
		public static final String kbn2= "計上_人工";
		/** 非計上_用役 */
		public static final String kbn3 = "非計上_用役";
		/** 非計上_人工 */
		public static final String kbn4 = "非計上_人工";
	}
	
	/** 賃金計上先タイプ */
	public static final class keijoGenkaCenterType{
		/** 現所属 */
		public static final String gen = "現所属";
		/** 応援派遣 */
		public static final String ouha = "応援派遣";
	}
	
	public static final class ShuseiTextType{
		/** 代表1行への入力 */
		public static final String type1 = "1";
		/** 変更行全てへの入力 */
		public static final String type2= "2";
	}

	/** 役職権限タイプ */
	public static final class postKengenType{
		/** 権限なし */
		public static final String NO_KENGEN = "";
		/** 上長権限*/
		public static final String APPROVAL = "1";
		
	}
	
	public static final String DUMMY = "DUMMY"; 
	
}
