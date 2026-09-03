#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "Oblez/Data/ShopItem.h"
#include "OblezShopCatalog.generated.h"

/// كتالوج عناصر متجر التطوير الثابت لمرحلة MVP.
/// كل فئة (عتاد/شبكة) مرتّبة بمستويات (Tier) متتالية بدءاً من 0
/// (المستوى الافتراضي المجاني)، وفئة الفلكس عناصر مستقلة بلا مستويات.
UCLASS()
class OBLEZ_API UOblezShopCatalog : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "Oblez|Shop")
	static TArray<FOblezShopItem> GetGearItems();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Shop")
	static TArray<FOblezShopItem> GetNetworkItems();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Shop")
	static TArray<FOblezShopItem> GetCosmeticItems();
};
