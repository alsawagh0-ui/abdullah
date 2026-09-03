#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "OblezPingLogic.generated.h"

/// منطق محاكاة البنق: كل ما زاد مستوى الشبكة، قلّت احتمالية ونسبة التقطيع.
/// MVP: نسبة عشوائية بسيطة، بدون أي حساب فيزيائي حقيقي للشبكة.
UCLASS()
class OBLEZ_API UOblezPingLogic : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/// نسبة حدوث "لاق سبايك" حسب مستوى الشبكة (0-4).
	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static float LagChance(int32 NetworkLevel);

	/// يرجّع true إذا صار تقطيع هالتك (يُستخدم بالـ Aim Trainer لتجاهل نقرة).
	UFUNCTION(BlueprintCallable, Category = "Oblez|Logic")
	static bool RollLagSpike(int32 NetworkLevel);
};
