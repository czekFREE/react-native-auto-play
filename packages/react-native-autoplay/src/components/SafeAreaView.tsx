import { View, type ViewProps } from 'react-native';
import { useSafeAreaInsets } from '../hooks/useSafeAreaInsets';

export const SafeAreaView = (props: ViewProps) => {
  const { style, ...rest } = props;
  const safeAreaInsets = useSafeAreaInsets();

  return (
    <View
      style={[
        style,
        {
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          paddingTop: safeAreaInsets.top,
          paddingBottom: safeAreaInsets.bottom,
          paddingRight: safeAreaInsets.right,
          paddingLeft: safeAreaInsets.left,
          pointerEvents: 'box-none',
        },
      ]}
      {...rest}
    />
  );
};
