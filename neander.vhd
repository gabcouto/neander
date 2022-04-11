library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity placa1 is

    Port ( reset : in  STD_LOGIC;			  

			  clk : in STD_LOGIC;
			  ledhalt : out STD_LOGIC);

end placa1;

architecture Behavioral of placa1 is

COMPONENT mem1

  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );

END COMPONENT;

type estados is (T0,T1,T2,T3,T4,T5,T6,T7);
signal estado : estados;
signal saidaULA, saidaACC, saidaMEM, saidaRI, saidaREM, saidaPC, saidaMUX, entradaMEM : std_logic_vector(7 downto 0);
signal sel, cargaREM, Rread, incPC, cargaACC, cargaNZ, cargaPC, cargaRI: std_logic;
signal selULA : STD_LOGIC_VECTOR(2 downto 0);
signal saidaNZ, saidaNZULA : STD_LOGIC_VECTOR(1 downto 0);
signal Wwrite : STD_LOGIC_VECTOR(0 downto 0);

begin

minha_memoria : mem1
  PORT MAP (
    clka => clk,
    wea => Wwrite,
    addra => saidaREM,
    dina => entradaMEM,
    douta => saidaMEM
  );

-- state machine
process(clk,reset)
begin
	if reset='1' then
		estado <= T0;
	elsif (clk='1' and clk'event) then
		case estado is
			when T0 =>
				estado <= T1;
			when T1 =>
				estado <= T2;
			when T2 =>
				estado <= T3;
			when T3 =>
				if saidaRI = "11010000" or saidaRI = "00000000" or saidaRI = "01100000" then 
					estado <= T0;
				elsif saidaRI = "11110000" then
					null;
				elsif saidaRI = "10010000" and saidaNZ(1) = '0' then
					estado <= T0;
				elsif	saidaRI = "10100000" and saidaNZ(0) = '0' then
					estado <= T0;
				else
					estado <= T4;
				end if;
			when T4 =>
				estado <= T5;
			when T5 =>
				if saidaRI = "10000000" then 
					estado <= T0;
				elsif saidaRI = "10010000" and saidaNZ(0) = '1' then
					estado <= T0;
				elsif saidaRI = "10100000" and saidaNZ(1) = '1' then
					estado <= T0;
				else
					estado <= T6;
				end if;
			when T6 =>
				estado <= T7;
			when T7 =>
				estado <= T0;
		end case;
	end if;
end process;

-- signals according to state
process(estado, saidaMEM, saidaRI, saidaPC, saidaNZ, saidaACC)
begin
	cargaREM <= '0';
	Rread <= '0';
	Wwrite <= "0";
	incPC <= '0';
	sel <= '1';
	cargaACC <= '0';
	cargaNZ <= '0';
	selULA <= "101"; -- default value
	cargaPC <= '0';
	cargaRI <= '0';
	entradaMEM <= "00000000";
	ledhalt <= '0';
		case estado is
			when T0 =>
				sel <= '0';
				cargaREM <= '1';
			when T1 =>
				Rread <= '1';
				incPC <= '1';
			when T2 =>
				cargaRI <= '1';
			when T3 =>
				if saidaRI = "01100000" then 
					cargaACC <= '1';
					cargaNZ <= '1';
					selULA <= "011";
				elsif saidaRI = "00000000" then
				elsif saidaRI = "10100000" and saidaNZ(0) = '0' then
					incPC <= '1';
				elsif saidaRI = "10010000" and saidaNZ(1) = '0' then
					incPC <= '1';
				elsif saidaRI = "11110000" then
					ledhalt <= '1';
				else
					sel <= '0';
					cargaREM <= '1';
				end if;
			when T4 =>
				if saidaRI = "10000000" or saidaRI = "10010000" or saidaRI = "10100000" then
					Rread <= '1';
				else
					Rread <= '1';
					incPC <= '1';
				end if;
			when T5 =>
				if saidaRI = "10000000" or saidaRI = "10010000" or saidaRI = "10100000" then
					cargaPC <= '1';
				else
					sel <= '1';
					cargaREM <= '1';
				end if;
			when T6 =>
				if saidaRI /= "00010000" then 
					Rread <= '1';
				end if;
			when T7 =>
				if saidaRI = "00010000" then 
					Wwrite <= "1";
					entradaMEM <= saidaACC;
				else
					cargaACC <= '1';
					cargaNZ <= '1';
					case saidaRI is
						when "00100000" => --lda
							selULA <= "101"; -- Y
						when "00110000" => -- add
							selULA <= "000"; -- add
						when "01000000" => -- or 
							selULA <= "010";  -- or 
						when "01010000" => -- and
							selULA <= "001"; -- and
						when "10100001" => -- SUB
							selULA <= "110";
						when "10100010" => -- XOR
							selULA <= "111";
						when others =>
							null;
					end case;
				end if;
		end case;
end process;

process(selULA, saidaACC, saidaULA, saidaPC, saidaMEM) -- ALU (portuguese: ULA)
begin
	case selULA is
		when "000" =>
			saidaULA <= std_logic_vector(unsigned(saidaMEM)+unsigned(saidaACC)); 
		when "001" =>
			saidaULA <= saidaMEM and saidaACC;
		when "010" =>
			saidaULA <= saidaMEM or saidaACC;
		when "011" =>
			saidaULA <= not saidaACC;
		when "100" =>
			saidaULA <= saidaACC;
		when "101" =>
			saidaULA <= saidaMEM; 
		when "110" => 
			saidaULA <= std_logic_vector(unsigned(saidaACC)-unsigned(saidaMEM));
		when "111" =>
			saidaULA <= saidaACC xor saidaMEM;
		when others =>
			saidaULA <= saidaACC;
	end case;
	if saidaULA = "00000000" then
		saidaNZULA(0) <= '1';
	else
		saidaNZULA(0) <= '0';
	end if;
	if saidaULA(7) = '1' then
		saidaNZULA(1) <= '1';
	else
		saidaNZULA(1) <= '0';
	end if;
end process;

process(sel, saidaPC, saidaMEM) -- MUX 
begin
	if sel = '0' then
		saidaMUX <= saidaPC;
	else
		saidaMUX <= saidaMEM;
	end if;
end process;

process(clk) -- REM register
begin
 if clk'event and clk='1' then
    if cargaREM = '1' then
      saidaREM <= saidaMUX;
    else
      saidaREM <= saidaREM;
    end if;
  end if;
end process;

process(clk) -- NZ register
begin
	if clk'event and clk='1' then
    if cargaNZ = '1' then
      saidaNZ <= saidaNZULA;
    else
      saidaNZ <= saidaNZ;
    end if;
  end if;
end process;

process(clk, reset) -- PC
begin
 if reset = '1' then
    saidaPC <= "00000000";
 elsif clk'event and clk='1' then
    if cargaPC = '1' then
      saidaPC <= saidaMEM;
    else
		if incPC = '1' then
			saidaPC <= std_logic_vector(1+unsigned(saidaPC));
		else
			saidaPC <= saidaPC;
		end if;
	 end if;
  end if;
end process;

process(clk) -- ACC
begin
	if clk'event and clk='1' then
		if cargaACC = '1' then
			saidaACC <= saidaULA;
		else
			saidaACC <= saidaACC;
		end if;
	end if;
end process;

process(clk) -- RI OK
begin
	if clk'event and clk='1' then
		if cargaRI = '1' then
			saidaRI <= saidaMEM;
		else
			saidaRI <= saidaRI;
		end if;
	end if;
end process;

end Behavioral;
