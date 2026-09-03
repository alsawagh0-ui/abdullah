#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "OblezGameModeBase.generated.h"

/**
 * وضع اللعبة الافتراضي. المنطق الفعلي (الغرفة، المتجر، Aim Trainer)
 * يُبنى كمستويات + Blueprints/UMG داخل الـ Editor، يستخدمون
 * UOblezPlayerProgress (GameInstanceSubsystem) كمصدر الحالة المشترك.
 */
UCLASS()
class OBLEZ_API AOblezGameModeBase : public AGameModeBase
{
	GENERATED_BODY()
};
