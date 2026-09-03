#include "OblezShopCatalog.h"

TArray<FOblezShopItem> UOblezShopCatalog::GetGearItems()
{
	return {
		FOblezShopItem{ FName("gear_basic"), NSLOCTEXT("Oblez", "GearBasic", "كرسي عادي"),
			EOblezShopCategory::Gear, 0, 0,
			NSLOCTEXT("Oblez", "GearBasicDesc", "كرسي المكتب الافتراضي — استنزاف طاقة عالي بالسهر الطويل.") },
		FOblezShopItem{ FName("gear_ergo"), NSLOCTEXT("Oblez", "GearErgo", "كرسي مريح"),
			EOblezShopCategory::Gear, 150, 1,
			NSLOCTEXT("Oblez", "GearErgoDesc", "دعم أفضل للظهر — يقلل استنزاف الطاقة بالساعة.") },
		FOblezShopItem{ FName("gear_pro"), NSLOCTEXT("Oblez", "GearPro", "كرسي قيمنق احترافي"),
			EOblezShopCategory::Gear, 400, 2,
			NSLOCTEXT("Oblez", "GearProDesc", "راحة كاملة لجلسات طويلة — أقل استنزاف طاقة ممكن.") },
	};
}

TArray<FOblezShopItem> UOblezShopCatalog::GetNetworkItems()
{
	return {
		FOblezShopItem{ FName("net_home"), NSLOCTEXT("Oblez", "NetHome", "راوتر منزلي ضعيف"),
			EOblezShopCategory::Network, 0, 0,
			NSLOCTEXT("Oblez", "NetHomeDesc", "الوضع الافتراضي — تقطيع متكرر أثناء اللعب.") },
		FOblezShopItem{ FName("net_upgraded"), NSLOCTEXT("Oblez", "NetUpgraded", "راوتر مطوّر"),
			EOblezShopCategory::Network, 200, 1,
			NSLOCTEXT("Oblez", "NetUpgradedDesc", "إشارة أقوى — يقلل احتمال التقطيع بالجولات.") },
		FOblezShopItem{ FName("net_fiber"), NSLOCTEXT("Oblez", "NetFiber", "ألياف ضوئية"),
			EOblezShopCategory::Network, 500, 2,
			NSLOCTEXT("Oblez", "NetFiberDesc", "سرعة واستقرار عاليين — تقطيع نادر جداً.") },
		FOblezShopItem{ FName("net_fiber_pro"), NSLOCTEXT("Oblez", "NetFiberPro", "ألياف ضوئية Pro"),
			EOblezShopCategory::Network, 900, 3,
			NSLOCTEXT("Oblez", "NetFiberProDesc", "أقصى استقرار ممكن قبل العقار — شبه بلا تقطيع.") },
	};
}

TArray<FOblezShopItem> UOblezShopCatalog::GetCosmeticItems()
{
	return {
		FOblezShopItem{ FName("cos_glasses"), NSLOCTEXT("Oblez", "CosGlasses", "نظارة قيمنق"),
			EOblezShopCategory::Cosmetic, 60, 0,
			NSLOCTEXT("Oblez", "CosGlassesDesc", "مظهر فقط — بلا أي تأثير وظيفي.") },
		FOblezShopItem{ FName("cos_headset"), NSLOCTEXT("Oblez", "CosHeadset", "سماعة مميزة"),
			EOblezShopCategory::Cosmetic, 90, 0,
			NSLOCTEXT("Oblez", "CosHeadsetDesc", "مظهر فقط — بلا أي تأثير وظيفي.") },
		FOblezShopItem{ FName("cos_bg"), NSLOCTEXT("Oblez", "CosBg", "خلفية غرفة نيون"),
			EOblezShopCategory::Cosmetic, 120, 0,
			NSLOCTEXT("Oblez", "CosBgDesc", "مظهر فقط — بلا أي تأثير وظيفي.") },
	};
}
