#include "OblezPlayerProgress.h"
#include "Oblez/Logic/OblezEnergyLogic.h"
#include "Oblez/Logic/OblezProgressionLogic.h"

void UOblezPlayerProgress::ChangeEnergy(int32 Amount)
{
	Energy = FMath::Clamp(Energy + Amount, 0, 100);
	OnChanged.Broadcast();
}

void UOblezPlayerProgress::AddMoney(int32 Amount)
{
	Money = FMath::Max(Money + Amount, 0);
	OnChanged.Broadcast();
}

void UOblezPlayerProgress::AddRankPoints(int32 Amount)
{
	RankPoints += Amount;
	RefreshTier();
	OnChanged.Broadcast();
}

void UOblezPlayerProgress::IgnoreManagerCall(int32 SalaryPenalty)
{
	MissedManagerCalls += 1;
	Money = FMath::Max(Money - SalaryPenalty, 0);
	if (IsFired())
	{
		bIsEmployed = false;
	}
	OnChanged.Broadcast();
}

void UOblezPlayerProgress::TickHour()
{
	Hour = (Hour + 1) % 24;
	Energy = FMath::Clamp(Energy - UOblezEnergyLogic::HourlyDrain(GearLevel), 0, 100);
	OnChanged.Broadcast();
}

bool UOblezPlayerProgress::RecordAimTrainerResult(int32 Score, int32& OutReward)
{
	OutReward = FMath::RoundToInt(Score / 5.0f);
	AddMoney(OutReward);
	AddRankPoints(Score);

	if (Score < RankLossScoreThreshold)
	{
		ConsecutiveRankLosses += 1;
	}
	else
	{
		ConsecutiveRankLosses = 0;
	}
	OnChanged.Broadcast();

	return IsKickedFromTeam();
}

void UOblezPlayerProgress::Sleep()
{
	Energy = FMath::Clamp(Energy + 40, 0, 100);
	Hour = 9;
	Day += 1;
	OnChanged.Broadcast();
}

bool UOblezPlayerProgress::BuyGearUpgrade(int32 ItemTier, int32 Price)
{
	if (ItemTier != GearLevel + 1 || Money < Price)
	{
		return false;
	}
	Money -= Price;
	GearLevel = ItemTier;
	RefreshTier();
	OnChanged.Broadcast();
	return true;
}

bool UOblezPlayerProgress::BuyNetworkUpgrade(int32 ItemTier, int32 Price)
{
	if (ItemTier != NetworkLevel + 1 || Money < Price)
	{
		return false;
	}
	Money -= Price;
	NetworkLevel = ItemTier;
	RefreshTier();
	OnChanged.Broadcast();
	return true;
}

bool UOblezPlayerProgress::BuyCosmetic(FName ItemId, int32 Price)
{
	if (OwnedCosmetics.Contains(ItemId) || Money < Price)
	{
		return false;
	}
	Money -= Price;
	OwnedCosmetics.Add(ItemId);
	OnChanged.Broadcast();
	return true;
}

bool UOblezPlayerProgress::BuyProperty()
{
	if (!CanBuyProperty())
	{
		return false;
	}
	Money -= PropertyPrice;
	Tier = EOblezProgressionTier::Ending;
	OnChanged.Broadcast();
	return true;
}

void UOblezPlayerProgress::ApplyDailyChoice(EOblezDailyChoice Choice)
{
	switch (Choice)
	{
	case EOblezDailyChoice::ExtraRank:
		ChangeEnergy(-15);
		AddRankPoints(25);
		break;
	case EOblezDailyChoice::ExtraWork:
		AddMoney(80);
		ChangeEnergy(-20);
		break;
	case EOblezDailyChoice::SleepEarly:
		if (MissedManagerCalls > 0)
		{
			MissedManagerCalls -= 1;
		}
		break;
	}
	Sleep();
}

void UOblezPlayerProgress::ResetGame()
{
	Energy = 100;
	Hour = 9;
	Day = 1;
	Money = 0;
	MissedManagerCalls = 0;
	NetworkLevel = 0;
	GearLevel = 0;
	Tier = EOblezProgressionTier::Beginner;
	bIsEmployed = true;
	RankPoints = 0;
	ConsecutiveRankLosses = 0;
	OwnedCosmetics.Empty();
	OnChanged.Broadcast();
}

void UOblezPlayerProgress::RefreshTier()
{
	if (Tier == EOblezProgressionTier::Ending)
	{
		return;
	}
	Tier = UOblezProgressionLogic::ComputeTier(GearLevel, NetworkLevel, RankPoints);
}
