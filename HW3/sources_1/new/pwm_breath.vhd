library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
entity pwm_breath is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_sw_up : in STD_LOGIC;
           i_sw_dn : in STD_LOGIC;           
           pwm : out STD_LOGIC);
end pwm_breath;
architecture Behavioral of pwm_breath is
signal           sw  : STD_LOGIC_VECTOR(1 downto 0);
signal   n_cycle_PWM : integer range 0 to 7000;
constant   default_n : integer := 5000;  -- default n pwm cycles
constant n_MIN_cycle : integer := 2000;   -- min n pwm cycles
constant n_MAX_cycle : integer := 7000; -- max n pwm cycles
constant       det_n : integer := 500;   -- delta n pwm cycles, one scale of n
signal brighter_darker : std_logic;
signal n_cycle_PWM_complete: std_logic;
signal prev_pwm_state: std_logic;
signal pwm_state: std_logic;
signal pwm_count: integer range 0 to 7000;
signal upbnd1: integer range 0 to 255;
signal upbnd2: integer range 0 to 255;
signal count1: integer range 0 to 255;
signal count2: integer range 0 to 255;

signal div     : std_logic_vector(60 downto 0);
signal e_clk  : std_logic;

begin
--�I�l�W�v�վ� breath frequency adaption, BFA
--input: 
    --sw_dn: �I�l��P(pwm�g�����ܤp)�A�I�l�W�v���W�դ@�Ө��, �@�Ө�׬��Ѽ� (16)
    --sw_up: �I�l�w�M(pwm�g�����ܤj)�A�I�l�W�v���U�դ@�Ө��
--output: 
    --n_cycle_PWM: pwm�`��n�Ӷg������A�� "�ո`" �l�t�νվ�upbnd1 & 2 (+1 or -1)
pwm <= pwm_state;
sw <= i_sw_up & i_sw_dn;
 
BFA:process(e_clk, i_rst, i_sw_up, i_sw_dn)
begin
    if i_rst = '0' then
        n_cycle_PWM <= default_n; 
    elsif e_clk'event and e_clk = '1' then
        case sw is
            when "00" => 
                null;
            when "01" => --�I�l��P(pwm�g�����ܤp)
                if n_cycle_PWM > n_MIN_cycle then
                    n_cycle_PWM <= n_cycle_PWM - det_n; -- tune down det_n
                else
                    null;
                end if; 
            when "10" => --�I�l��w(pwm�g�����ܤj)
                if n_cycle_PWM < n_MAX_cycle then
                    n_cycle_PWM <= n_cycle_PWM + det_n; -- tune up det_n
                else
                    null;
                end if;             
            when "11" =>
                null;
            when others =>
                null;
        end case;
    end if;
end process;
--�ո`Adapt: �p�ƾ����W���Ƚհ�/�C ==> PWM High/Low ��ҽհ�(�իG)�Ϊ̽էC(�ܷt)
--input: 
    --n_cycle_PWM: pwm�`��n�Ӷg������A�� "�ո`" �l�t�νվ�upbnd1 & 2 (+1 or -1)
    --upbnd1: 
    --upbnd2:
    --pwm(state):
--output:
    --brighter_darker = '1' : counter1�p�ƤW����"��"1�Ө�� "�P��"  counter2�W����"�C"�@�Ө�� ==> Brighter 
    --brighter_darker = '0' : counter1�p�ƤW����"�C"1�Ө�� "�P��"  counter2�W����"��"�@�Ө�� ==> Darker 
Adapt_brighter_or_darker:process(i_clk, i_rst, upbnd1, upbnd2)
begin
    if i_rst = '0' then
        brighter_darker <= '1'; 
    elsif i_clk'event and i_clk = '1' then
        if brighter_darker = '0' then
            if upbnd1=0 then -- counter2=MAX_PWM_count�̷t��
                brighter_darker <= '1';
            end if;
        else --brighter_darker = '1'
            if upbnd2=0 then -- counter1=MAX_PWM_count�̫G��
                brighter_darker <= '0';
            end if;        
        end if;
    end if;
end process;
--input:
    -- pwm: pwm state feedback;
--output:
    -- n_PWM_cycle_complete: already counted n PWM cycles according to num of pwm pulses
PWM_cycle_counter:process(i_clk, i_rst, n_cycle_PWM, pwm_state)
begin
    if i_rst = '0' then
        n_cycle_PWM_complete <= '0'; 
        pwm_count <= 0;
        prev_pwm_state <= '0';
    elsif i_clk'event and i_clk = '1' then
        prev_pwm_state <= pwm_state; -- Mealey Machine
        if prev_pwm_state = '0' and pwm_state = '1' then
            if pwm_count < n_cycle_PWM then
                pwm_count <= pwm_count + 1;
                n_cycle_PWM_complete <= '0'; -- not yet
            else
                n_cycle_PWM_complete <= '1'; -- ���� PWM �g��
                pwm_count <= 0; -- �i�J�U�@�� PWM �g��
            end if;
        elsif prev_pwm_state = '1' and pwm_state = '0' then
            if pwm_count < n_cycle_PWM then
                pwm_count <= pwm_count + 1;
                n_cycle_PWM_complete <= '0'; -- not yet
            else
                n_cycle_PWM_complete <= '1'; -- ���� PWM �g��
                pwm_count <= 0; -- �i�J�U�@�� PWM �g��
            end if;
        else
            n_cycle_PWM_complete <= '0'; -- null;
        end if;
    end if;
end process;
--inputs:
    -- brighter_darker: 
    -- n_cycle_PWM_complete: ����n��cycle PWM�g��
--outputs:
    -- upbnd1, upbnd2        
upperbounds:process(i_clk, i_rst, brighter_darker, n_cycle_PWM_complete)
begin
    if i_rst = '0' then
        upbnd1 <= 0;
        upbnd2 <= 255;        
    elsif i_clk'event and i_clk = '1' then
         if brighter_darker = '0' then
             if n_cycle_PWM_complete = '1' then
                 upbnd1 <= upbnd1 - 1;
                 upbnd2 <= upbnd2 + 1;
             else
                 null;
             end if;
         else -- brighter_darker = '1'
             if n_cycle_PWM_complete = '1' then
                 upbnd1 <= upbnd1 + 1;
                 upbnd2 <= upbnd2 - 1;
             else
                 null;
             end if;         
         end if;
    end if;
end process;
-----PWM component: 
--inputs: count1, count2
--output: pwm_state
FSM1_for_pwm: process(i_rst, i_clk, count1, count2)
begin
    if i_rst = '0' then
        pwm_state <= '0';
    elsif i_clk'event and i_clk = '1' then
        if pwm_state = '0' then
            if count1 = upbnd1 then
                pwm_state <= '1';
            else
                pwm_state <= '0';
            end if;
        else -- pwm_state = '1'
            if count2 = upbnd2 then
                pwm_state <= '0';
            else
                pwm_state <= '1';
            end if;    
        end if;        
    end if;
end process;
counter1:process(i_clk, i_rst, pwm_state)
begin
    if i_rst = '0' then
        count1 <= 0;
    elsif i_clk'event and i_clk = '1' then
        if pwm_state = '0' then
            count1 <= count1 + 1;
            --count2 <= 0;
        else -- pwm_state = '1'
            count1 <= 0;
        end if;   
    end if;
end process;
counter2:process(i_clk, i_rst, pwm_state)
begin
    if i_rst = '0' then
        count2 <= 0;
    elsif i_clk'event and i_clk = '1' then
        if pwm_state = '1' then
            count2 <= count2 + 1;
            --count2 <= 0;
        else -- pwm_state = '0'
            count2 <= 0;
        end if;   
    end if;
end process;
div_clk : process(i_clk, i_rst)
begin
    if i_rst = '0' then
        div <= (others => '0');
    elsif rising_edge(i_clk) then
        div <= div + 1;
    end if;
end process;
e_clk <= div(24);
end Behavioral;


