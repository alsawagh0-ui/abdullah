#include "OblezAimTrainerLogic.h"

FVector2D UOblezAimTrainerLogic::RandomPosition(float Margin)
{
	const float X = Margin + FMath::FRand() * (1.f - Margin * 2.f);
	const float Y = Margin + FMath::FRand() * (1.f - Margin * 2.f);
	return FVector2D(X, Y);
}

float UOblezAimTrainerLogic::TargetLifetimeSeconds(int32 Combo)
{
	const int32 Ms = FMath::Clamp(1400 - Combo * 20, 500, 1400);
	return Ms / 1000.0f;
}

int32 UOblezAimTrainerLogic::ScoreForHit(int32 Combo)
{
	return 10 + (Combo / 5) * 2;
}

FVector2D UOblezAimTrainerLogic::JitterOffset(float Magnitude)
{
	const float Dx = (FMath::FRand() * 2.f - 1.f) * Magnitude;
	const float Dy = (FMath::FRand() * 2.f - 1.f) * Magnitude;
	return FVector2D(Dx, Dy);
}
