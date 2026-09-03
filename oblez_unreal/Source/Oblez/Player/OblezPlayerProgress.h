#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Oblez/Data/OblezTypes.h"
#include "OblezPlayerProgress.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOblezPlayerProgressChanged);

/**
 * حالة اللاعب المركزية — GameInstanceSubsystem يعيش طول جلسة اللعب بلا
 * حاجة لتمريره يدوياً بين المستويات. يقابل PlayerState (ChangeNotifier)
 * بنسخة Flutter الأصلية تماماً حقل بحقل ودالة بدالة.
 *
 * ملاحظة تسمية: هذا الصف غير مرتبط إطلاقاً بصف Unreal المدمج APlayerState
 * (خاص بالشبكي/الـ replication) — الاسم مأخوذ من دلالة "حالة اللاعب"
 * بتصميم اللعبة نفسه، مو من نظام Unreal.
 *
 * الربط بالواجهة: OnChanged دايناميكي (BlueprintAssignable) — من أي Widget
 * Blueprint اعمل "Bind Event to OnChanged" واربطه بدالة تحدّث كل عناصر
 * العرض. يصير Broadcast تلقائياً بكل Setter هنا، تماماً يقابل استخدام
 * Provider/notifyListeners() بنسخة Flutter.
 */
UCLASS(BlueprintType)
class OBLEZ_API UOblezPlayerProgress : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/// يُطلق بعد أي تعديل على الحالة — اربط عليه من الـ Widget Blueprint.
	UPROPERTY(BlueprintAssignable, Category = "Oblez|Player")
	FOblezPlayerProgressChanged OnChanged;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 Energy = 100;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 Hour = 9;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 Day = 1;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 Money = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 MissedManagerCalls = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 NetworkLevel = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 GearLevel = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	EOblezProgressionTier Tier = EOblezProgressionTier::Beginner;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	bool bIsEmployed = true;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 RankPoints = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	int32 ConsecutiveRankLosses = 0;

	UPROPERTY(BlueprintReadOnly, Category = "Oblez|Player")
	TArray<FName> OwnedCosmetics;

	/// سعر الهدف النهائي (عقار = بنق مستقر 0ms، شاشة الفوز).
	static constexpr int32 PropertyPrice = 5000;

	/// أي جولة Aim Trainer بنقاط أقل من هالحد تُحسب "خسارة رانك".
	static constexpr int32 RankLossScoreThreshold = 50;

	/// عدد الخسائر المتتالية اللي تؤدي للطرد من الفريق.
	static constexpr int32 MaxConsecutiveRankLosses = 3;

	UFUNCTION(BlueprintPure, Category = "Oblez|Player")
	bool IsFired() const { return MissedManagerCalls >= 3; }

	UFUNCTION(BlueprintPure, Category = "Oblez|Player")
	bool IsKickedFromTeam() const { return ConsecutiveRankLosses >= MaxConsecutiveRankLosses; }

	UFUNCTION(BlueprintPure, Category = "Oblez|Player")
	bool CanBuyProperty() const { return Tier == EOblezProgressionTier::Pro && Money >= PropertyPrice; }

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void ChangeEnergy(int32 Amount);

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void AddMoney(int32 Amount);

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void AddRankPoints(int32 Amount);

	/// اتصال مدير متجاهل: خصم من الراتب + إنذار يتراكم، وعند الثالث يُفصل اللاعب.
	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void IgnoreManagerCall(int32 SalaryPenalty = 50);

	/// تقدّم فعلي بالوقت أثناء اللعب: كل نداء يمثّل ساعة، ويستنزف طاقة حسب
	/// مستوى العتاد. نادِها من Timer داخل مستوى الغرفة (Blueprint/C++).
	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void TickHour();

	/// نتيجة جولة Aim Trainer: يحدّث الفلوس ونقاط الرانك، ويتابع سلسلة خسائر
	/// الرانك. يرجّع true لو انطرد اللاعب من الفريق (3 خسائر متتالية).
	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	bool RecordAimTrainerResult(int32 Score, int32& OutReward);

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void Sleep();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	bool BuyGearUpgrade(int32 ItemTier, int32 Price);

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	bool BuyNetworkUpgrade(int32 ItemTier, int32 Price);

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	bool BuyCosmetic(FName ItemId, int32 Price);

	/// شراء الهدف النهائي: عقار = بنق مستقر 0ms. يتطلب مرحلة "المحترف".
	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	bool BuyProperty();

	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void ApplyDailyChoice(EOblezDailyChoice Choice);

	/// يرجّع كل الإحصائيات لبداية جديدة — يُستخدم بزر "من جديد" بشاشة الفشل.
	UFUNCTION(BlueprintCallable, Category = "Oblez|Player")
	void ResetGame();

private:
	/// يعيد حساب مرحلة التقدم من الإحصائيات الحالية، بدون المساس بمرحلة
	/// النهاية بعد ما تتحقق (تُفعّل فقط عبر BuyProperty).
	void RefreshTier();
};
