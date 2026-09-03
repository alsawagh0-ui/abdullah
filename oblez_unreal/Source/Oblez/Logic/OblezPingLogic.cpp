#include "OblezPingLogic.h"

float UOblezPingLogic::LagChance(int32 NetworkLevel)
{
	static const float BaseChances[] = { 0.35f, 0.22f, 0.12f, 0.05f, 0.01f };
	const int32 Level = FMath::Clamp(NetworkLevel, 0, UE_ARRAY_COUNT(BaseChances) - 1);
	return BaseChances[Level];
}

bool UOblezPingLogic::RollLagSpike(int32 NetworkLevel)
{
	return FMath::FRand() < LagChance(NetworkLevel);
}
