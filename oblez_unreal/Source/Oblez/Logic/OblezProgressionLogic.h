#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "Oblez/Data/OblezTypes.h"
#include "OblezProgressionLogic.generated.h"

/// يحسب مرحلة التقدم الحالية بناءً على ترقيات العتاد/الشبكة ونقاط الرانك.
/// ما يرجّع أبداً EOblezProgressionTier::Ending — تلك تُفعّل فقط بشراء
/// العقار صراحة عبر UOblezPlayerProgress::BuyProperty، مو بحساب تلقائي.
UCLASS()
class OBLEZ_API UOblezProgressionLogic : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static EOblezProgressionTier ComputeTier(int32 GearLevel, int32 NetworkLevel, int32 RankPoints);

	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static FText LabelFor(EOblezProgressionTier Tier);
};
