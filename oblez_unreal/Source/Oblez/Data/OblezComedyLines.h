#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "OblezComedyLines.generated.h"

/// بنك نصوص كوميدي عشوائي، بعربية عامة مبسطة بلا لهجة محلية ضيقة —
/// نفس بنك نصوص نسخة Flutter، منقول هنا بمصفوفات FText.
UCLASS()
class OBLEZ_API UOblezComedyLines : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetManagerCalls();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetFamilyReactions();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetHypeComments();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetLagSpikeLines();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetLevelUpTaunts();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetRankDownTaunts();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetFiredReasons();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static TArray<FText> GetKickedReasons();

	/// يرجّع سطر عشوائي من مصفوفة نصوص — يفيد بربطه مباشرة ببلوبرنت.
	UFUNCTION(BlueprintCallable, Category = "Oblez|Comedy")
	static FText RandomLine(const TArray<FText>& Lines);
};
