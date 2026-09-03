#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "OblezAimTrainerLogic.generated.h"

/// منطق توليد الأهداف وحساب النقاط لـ Aim Trainer، بمعزل عن الواجهة/المستوى
/// عشان يسهل اختباره بدون تشغيل اللعبة كاملة.
UCLASS()
class OBLEZ_API UOblezAimTrainerLogic : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/// موضع عشوائي نسبي (0.0-1.0) داخل منطقة اللعب، بهامش أمان من الحواف.
	UFUNCTION(BlueprintCallable, Category = "Oblez|Logic")
	static FVector2D RandomPosition(float Margin = 0.12f);

	/// عمر الهدف بالثواني قبل ما يختفي؛ يقصر شوي كل ما زاد الكومبو (تحدي أعلى).
	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static float TargetLifetimeSeconds(int32 Combo);

	/// نقاط الإصابة الواحدة، تزيد مع الكومبو.
	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static int32 ScoreForHit(int32 Combo);

	/// إزاحة عشوائية صغيرة (تهز الهدف) تُستخدم لما طاقة اللاعب منخفضة.
	UFUNCTION(BlueprintCallable, Category = "Oblez|Logic")
	static FVector2D JitterOffset(float Magnitude = 0.03f);
};
