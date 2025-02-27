/*
 *  SNOWPACK stand-alone
 *
 *  Copyright WSL Institute for Snow and Avalanche Research SLF, DAVOS, SWITZERLAND
*/
/*  This file is part of Snowpack.
    Snowpack is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Snowpack is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Snowpack.  If not, see <http://www.gnu.org/licenses/>.
*/
/**
 * @file SeaIce.h
 * @version 10.02
 * This header file contains all the data structures needed for the 1d snowpack model
 */

#ifndef SEAICE_H
#define SEAICE_H

#include <snowpack/DataClasses.h>

#include <meteoio/MeteoIO.h>
#include <vector>
#include <string>

// Forward-declare classes
class ElementData;
class SnowStation;
class CurrentMeteo;
class BoundCond;
class SurfaceFluxes;

class SeaIce {
	public:
		SeaIce();
		~SeaIce();
		void ConfigSeaIce(const SnowpackConfig& i_cfg);
		SeaIce& operator=(const SeaIce&); ///<Assignement operator
		constexpr SeaIce(const SeaIce& org) = default;

		//SeaIce(const SnowpackConfig& i_cfg);
		static double compSeaIceHeatCapacity(const double& T, const double& Sal);
		static double compSeaIceThermalConductivity(const ElementData& Edata);
		static double compSeaIceLatentHeatFusion(const ElementData& Edata);
		static double compSeaIceLatentHeatFusion(const double& T, const double& Sal);
		double calculateBrineSalinity(const double& T);
		double calculateMeltingTemperature(const double& Sal);

		const static double SeaWaterFreezingTemp;
		const static double SeaIceDensity;
		const static double ice_threshold;
		const static double mu;
		const static double betaS;
		const static double ThicknessFirstIceLayer;
		const static double InitRg;
		const static double InitRb;
		const static double OceanSalinity;
		const static double InitSeaIceSalinity;
		const static double InitSnowSalinity;

		double SeaLevel;            ///< Sea level in domain (m)
		double ForcedSeaLevel;      ///< Force sea level externally (Alpine3D)
		double FreeBoard;           ///< Freeboard of sea ice (m)
		double IceSurface;          ///< Interface sea ice/snow (m)
		size_t IceSurfaceNode;      ///< Interface node sea ice/snow (m)
		double OceanHeatFlux;       ///< Ocean heat flux (W/m^2)

		double BottomSalFlux, TopSalFlux;	//Bottom and top salt flux

		bool check_initial_conditions;
		enum salinityprofiles{NONE, CONSTANT, COXANDWEEKS, LINEARSAL, LINEARSAL2, SINUSSAL};
		salinityprofiles salinityprofile;
		enum thermalmodels{IGNORE, ASSUR1958, VANCOPPENOLLE2019, VANCOPPENOLLE2019_M};
		thermalmodels thermalmodel;


		friend std::iostream& operator<<(std::iostream& os, const SeaIce& data);
		friend std::iostream& operator>>(std::iostream& is, SeaIce& data);

		void calculateMeltingTemperature(ElementData& Edata);
		std::pair<double, double>getMu(const double& Sal);
		void compSalinityProfile(SnowStation& Xdata);
		void updateFreeboard(SnowStation& Xdata);
		double findIceSurface(SnowStation& Xdata);
		void compFlooding(SnowStation& Xdata, SurfaceFluxes& Sdata);
		void bottomIceFormation(SnowStation& Xdata, const CurrentMeteo& Mdata, const double& sn_dt, SurfaceFluxes& Sdata);
		void ApplyBottomIceMassBalance(SnowStation& Xdata, const CurrentMeteo& Mdata, double dM, SurfaceFluxes& Sdata);

		double getAvgBulkSalinity(const SnowStation& Xdata);
		double getAvgBrineSalinity(const SnowStation& Xdata);
		double getTotSalinity(const SnowStation& Xdata);

		void InitSeaIce(SnowStation& Xdata);

		void runSeaIceModule(SnowStation& Xdata, const CurrentMeteo& Mdata, BoundCond& Bdata, const double& sn_dt, SurfaceFluxes& Sdata);

}; //end class Snowpack

#endif
