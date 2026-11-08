package body Colony_Names is

   function Land_Name (Key, Index : Natural) return String is
   begin
      case Key is
         when 0 =>
            case Index is
               when 0 => return "Anvil Ridge";
               when 1 => return "Bastion Hale";
               when 2 => return "Forgecrest";
               when 3 => return "Iron Watch";
               when 4 => return "Rampart Nine";
               when 5 => return "Sentinel Rock";
               when 6 => return "Hammerfall";
               when 7 => return "Citadel Gray";
               when 8 => return "Breakline";
               when 9 => return "Garrison Deep";
               when 10 => return "Bulwark";
               when 11 => return "Ironmoor";
               when 12 => return "Steelhaven";
               when 13 => return "Vanguard Post";
               when 14 => return "Crucible";
               when 15 => return "Shieldwall";
               when 16 => return "Redoubt";
               when 17 => return "Ember Barracks";
               when 18 => return "Talon Point";
               when 19 => return "Ordnance Flats";
               when 20 => return "Keepstone";
               when 21 => return "Cinderhold";
               when 22 => return "Salvo Ridge";
               when 23 => return "Gauntlet";
               when 24 => return "Lancer Field";
               when 25 => return "Drill Yard";
               when 26 => return "Warden Spire";
               when 27 => return "Bracer Hill";
               when 28 => return "Flintmark";
               when 29 => return "Muster Plain";
               when 30 => return "Ironbark";
               when 31 => return "Cobalt Gate";
               when 32 => return "Holdfast";
               when 33 => return "Arsenal Rise";
               when 34 => return "Granite Line";
               when 35 => return "Barricade";
               when 36 => return "Cannon Hollow";
               when 37 => return "Siegeworks";
               when 38 => return "Stalwart";
               when 39 => return "Last Bastion";
               when others => return "";
            end case;
         when 1 =>
            case Index is
               when 0 => return "Prism Hall";
               when 1 => return "Lyceum One";
               when 2 => return "Lantern Quay";
               when 3 => return "Axiom Fields";
               when 4 => return "Halo Archive";
               when 5 => return "Index";
               when 6 => return "Candela";
               when 7 => return "Theorem Rise";
               when 8 => return "Clearview";
               when 9 => return "Spectra";
               when 10 => return "Margin Notes";
               when 11 => return "Cogito";
               when 12 => return "Lumen Prime";
               when 13 => return "Parallax";
               when 14 => return "Proof Hill";
               when 15 => return "Quillmere";
               when 16 => return "Refraction";
               when 17 => return "Scholar Gate";
               when 18 => return "Tessellate";
               when 19 => return "Vellum";
               when 20 => return "Wavefront";
               when 21 => return "Zenith Lab";
               when 22 => return "Brightglass";
               when 23 => return "Orrery";
               when 24 => return "Corpus";
               when 25 => return "Equinox Study";
               when 26 => return "Aperture";
               when 27 => return "Glimmerden";
               when 28 => return "Reckoning";
               when 29 => return "Postulate";
               when 30 => return "Concord Library";
               when 31 => return "Lucent Bay";
               when 32 => return "Paradigm";
               when 33 => return "Stillpoint";
               when 34 => return "First Lemma";
               when 35 => return "Focal Point";
               when 36 => return "Hypothesis";
               when 37 => return "Whitestone Hall";
               when 38 => return "Observatory Ridge";
               when 39 => return "Last Light";
               when others => return "";
            end case;
         when 2 =>
            case Index is
               when 0 => return "Mossheart";
               when 1 => return "Rootfall";
               when 2 => return "Fernhollow";
               when 3 => return "Sporewell";
               when 4 => return "Greenmantle";
               when 5 => return "Thicket Rest";
               when 6 => return "Lichenreach";
               when 7 => return "Bloomvale";
               when 8 => return "Mycel Grove";
               when 9 => return "Seedcradle";
               when 10 => return "Willowmere";
               when 11 => return "Bramblewood";
               when 12 => return "Canopy";
               when 13 => return "Dewfall";
               when 14 => return "Groundsong";
               when 15 => return "Hearthroot";
               when 16 => return "Ivycross";
               when 17 => return "Kindred Glade";
               when 18 => return "Leafhome";
               when 19 => return "Marrow Moss";
               when 20 => return "Nettlebrook";
               when 21 => return "Oakshade";
               when 22 => return "Pollen Fields";
               when 23 => return "Quietroot";
               when 24 => return "Rainwreath";
               when 25 => return "Sapling";
               when 26 => return "Tanglewood";
               when 27 => return "Understory";
               when 28 => return "Verdance";
               when 29 => return "Wildbloom";
               when 30 => return "Yarrowmeet";
               when 31 => return "Barkcircle";
               when 32 => return "Cedarkeep";
               when 33 => return "Driftmoss";
               when 34 => return "Elderwild";
               when 35 => return "Fungal Choir";
               when 36 => return "Gladesend";
               when 37 => return "Humus Deep";
               when 38 => return "Kelpwater";
               when 39 => return "Gentle Return";
               when others => return "";
            end case;
         when 3 =>
            case Index is
               when 0 => return "Freeport Dust";
               when 1 => return "Coin Hollow";
               when 2 => return "Ledger Rock";
               when 3 => return "Tradewind";
               when 4 => return "Bargain Flats";
               when 5 => return "Caravan Rest";
               when 6 => return "Dividend";
               when 7 => return "Exchange Point";
               when 8 => return "Fairmarket";
               when 9 => return "Gilded Mile";
               when 10 => return "Haggle Cross";
               when 11 => return "Interest Ridge";
               when 12 => return "Jobbers Gap";
               when 13 => return "Kiosk Town";
               when 14 => return "Lucky Strike";
               when 15 => return "Merchant Spur";
               when 16 => return "Netprofit";
               when 17 => return "Outfitter";
               when 18 => return "Payday";
               when 19 => return "Quota";
               when 20 => return "Rally Market";
               when 21 => return "Surplus";
               when 22 => return "Tariff Gate";
               when 23 => return "Underwriter";
               when 24 => return "Venture Camp";
               when 25 => return "Waybill";
               when 26 => return "Yieldmark";
               when 27 => return "Brokers Rest";
               when 28 => return "Crossroads Bazaar";
               when 29 => return "Depot Seven";
               when 30 => return "Escrow";
               when 31 => return "Futures";
               when 32 => return "Goldrush";
               when 33 => return "Hawker Hill";
               when 34 => return "Bounty Flats";
               when 35 => return "Last Chance";
               when 36 => return "Margin Call";
               when 37 => return "New Prospect";
               when 38 => return "Openhand";
               when 39 => return "Profit Rise";
               when others => return "";
            end case;
         when others => return "";
      end case;
   end Land_Name;

   function Sea_Name (Key, Index : Natural) return String is
   begin
      case Key is
         when 0 =>
            case Index is
               when 0 => return "Ironkeel";
               when 1 => return "Breakwater Fort";
               when 2 => return "Harbor Bastion";
               when 3 => return "Tidewall";
               when 4 => return "Seagate Nine";
               when 5 => return "Saltforge";
               when 6 => return "Anchor Hold";
               when 7 => return "Riptide Station";
               when 8 => return "Coral Rampart";
               when 9 => return "Deepwatch";
               when 10 => return "Gunwale";
               when 11 => return "Stormmoor";
               when others => return "";
            end case;
         when 1 =>
            case Index is
               when 0 => return "Tidal Lens";
               when 1 => return "Refractor Isle";
               when 2 => return "Pelagic Study";
               when 3 => return "Brine Archive";
               when 4 => return "Lumen Shoal";
               when 5 => return "Reflection Deep";
               when 6 => return "Saline Prism";
               when 7 => return "Wave Theory";
               when 8 => return "Abyss Lab";
               when 9 => return "Coral Index";
               when 10 => return "Glass Atoll";
               when 11 => return "Undertow Lyceum";
               when others => return "";
            end case;
         when 2 =>
            case Index is
               when 0 => return "Kelpcradle";
               when 1 => return "Reefsong";
               when 2 => return "Tidemoss";
               when 3 => return "Saltbloom";
               when 4 => return "Coral Garden";
               when 5 => return "Seagrass Rest";
               when 6 => return "Brine Grove";
               when 7 => return "Driftweed";
               when 8 => return "Anemone";
               when 9 => return "Pearlroot";
               when 10 => return "Wavefern";
               when 11 => return "Lagoon Heart";
               when others => return "";
            end case;
         when 3 =>
            case Index is
               when 0 => return "Freeport Tide";
               when 1 => return "Cargo Reef";
               when 2 => return "Dockside";
               when 3 => return "Bounty Bay";
               when 4 => return "Wharf Nine";
               when 5 => return "Salvage Point";
               when 6 => return "Smuggler Cove";
               when 7 => return "Tollwater";
               when 8 => return "Brine Market";
               when 9 => return "Pier Prosperity";
               when 10 => return "Seabond";
               when 11 => return "Harbor Ledger";
               when others => return "";
            end case;
         when others => return "";
      end case;
   end Sea_Name;

   function Land_Count (Key : Natural) return Natural is
   begin
      case Key is
         when 0 => return 40;
         when 1 => return 40;
         when 2 => return 40;
         when 3 => return 40;
         when others => return 0;
      end case;
   end Land_Count;

   function Sea_Count (Key : Natural) return Natural is
   begin
      case Key is
         when 0 => return 12;
         when 1 => return 12;
         when 2 => return 12;
         when 3 => return 12;
         when others => return 0;
      end case;
   end Sea_Count;

   function Faction_Name (Key : Natural) return String is
   begin
      case Key is
         when 0 => return "Iron Meridian";
         when 1 => return "Lumen Collective";
         when 2 => return "Verdant Covenant";
         when 3 => return "Free Drift Syndicate";
         when others => return "Faction";
      end case;
   end Faction_Name;

   function Leader (Key : Natural) return String is
   begin
      case Key is
         when 0 => return "Marshal Okonkwo-Hale";
         when 1 => return "Provost Ilse Varga";
         when 2 => return "Warden Tamsin Reyes";
         when 3 => return "Broker Anselm Kade";
         when others => return "";
      end case;
   end Leader;

   function Fallback_Count return Natural is (24);

   function Fallback (Index : Natural) return String is
   begin
      case Index is
         when 0 => return "Firstlight";
         when 1 => return "Hollow Reach";
         when 2 => return "Cinder Gate";
         when 3 => return "Saltmere";
         when 4 => return "Quietwater";
         when 5 => return "Brightfall";
         when 6 => return "Ember Rise";
         when 7 => return "Glassmoor";
         when 8 => return "Dunmarrow";
         when 9 => return "Halcyon";
         when 10 => return "Thornvale";
         when 11 => return "Lowharbor";
         when 12 => return "Skyrest";
         when 13 => return "Ironroot";
         when 14 => return "Mistral";
         when 15 => return "Ashgrove";
         when 16 => return "Coldspring";
         when 17 => return "Northwake";
         when 18 => return "Redfen";
         when 19 => return "Sablecrest";
         when 20 => return "Tidewell";
         when 21 => return "Umberly";
         when 22 => return "Verity";
         when 23 => return "Wanderhold";
         when others => return "";
      end case;
   end Fallback;

end Colony_Names;
