#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "OblezEnergyLogic.generated.h"

/// منطق استنزاف/استرجاع الطاقة، بمعزل عن حالة اللاعب عشان يسهل اختباره.
UCLASS()
class OBLEZ_API UOblezEnergyLogic : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/// استنزاف الطاقة بالساعة أثناء السهر (يقل مع ترقية الكرسي/العتاد).
	UFUNCTION(BlueprintCallable, Category = "Oblez|Logic")
	static int32 HourlyDrain(int32 GearLevel);

	/// هل الطاقة منخفضة بدرجة تأثر على الأداء (اهتزاز مؤشر، تأخر استجابة)؟
	UFUNCTION(BlueprintPure, Category = "Oblez|Logic")
	static bool IsLow(int32 Energy);
};
