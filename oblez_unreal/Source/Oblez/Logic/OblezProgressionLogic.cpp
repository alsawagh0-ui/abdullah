#include "OblezProgressionLogic.h"

EOblezProgressionTier UOblezProgressionLogic::ComputeTier(int32 GearLevel, int32 NetworkLevel, int32 RankPoints)
{
	if (GearLevel >= 2 && NetworkLevel >= 2 && RankPoints >= 150)
	{
		return EOblezProgressionTier::Pro;
	}
	if (GearLevel >= 1 && NetworkLevel >= 1)
	{
		return EOblezProgressionTier::Skilled;
	}
	return EOblezProgressionTier::Beginner;
}

FText UOblezProgressionLogic::LabelFor(EOblezProgressionTier Tier)
{
	switch (Tier)
	{
	case EOblezProgressionTier::Beginner:
		return NSLOCTEXT("Oblez", "TierBeginner", "المبتدئ");
	case EOblezProgressionTier::Skilled:
		return NSLOCTEXT("Oblez", "TierSkilled", "المتمكن");
	case EOblezProgressionTier::Pro:
		return NSLOCTEXT("Oblez", "TierPro", "المحترف");
	case EOblezProgressionTier::Ending:
		return NSLOCTEXT("Oblez", "TierEnding", "الأسطورة");
	default:
		return FText::GetEmpty();
	}
}
