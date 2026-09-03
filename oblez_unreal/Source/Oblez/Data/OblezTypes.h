#pragma once

#include "CoreMinimal.h"
#include "OblezTypes.generated.h"

/// مراحل التقدم بالقصة — تقابل ProgressionTier بنسخة Flutter الأصلية.
UENUM(BlueprintType)
enum class EOblezProgressionTier : uint8
{
	Beginner,
	Skilled,
	Pro,
	Ending
};

/// القرار اليومي بنهاية كل يوم — يقابل DailyChoice بنسخة Flutter.
UENUM(BlueprintType)
enum class EOblezDailyChoice : uint8
{
	ExtraRank,
	ExtraWork,
	SleepEarly
};

/// فئات عناصر متجر التطوير الثلاث.
UENUM(BlueprintType)
enum class EOblezShopCategory : uint8
{
	Gear,
	Network,
	Cosmetic
};
