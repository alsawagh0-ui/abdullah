#include "OblezEnergyLogic.h"

int32 UOblezEnergyLogic::HourlyDrain(int32 GearLevel)
{
	static const int32 BaseDrain[] = { 6, 4, 2 };
	const int32 Level = FMath::Clamp(GearLevel, 0, UE_ARRAY_COUNT(BaseDrain) - 1);
	return BaseDrain[Level];
}

bool UOblezEnergyLogic::IsLow(int32 Energy)
{
	return Energy <= 30;
}
