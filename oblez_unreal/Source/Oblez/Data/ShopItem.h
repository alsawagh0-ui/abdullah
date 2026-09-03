#pragma once

#include "CoreMinimal.h"
#include "Oblez/Data/OblezTypes.h"
#include "ShopItem.generated.h"

/// عنصر واحد في متجر التطوير (كرسي، راوتر، نظارة قيمنق...).
/// ملاحظة: بدون حقل أيقونة هنا (خلافاً لنسخة Flutter) — أيقونات/صور
/// المتجر أصول بصرية (Texture2D) تُربط بالـ Id من داخل الـ Editor
/// (UMG/Data Table)، مو نص يُكتب بالكود.
USTRUCT(BlueprintType)
struct FOblezShopItem
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	FName Id;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	FText Name;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	EOblezShopCategory Category = EOblezShopCategory::Gear;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	int32 Price = 0;

	/// مستوى الترقية داخل فئته (0 = الأساسي/الافتراضي).
	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	int32 Tier = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Shop")
	FText Description;
};
